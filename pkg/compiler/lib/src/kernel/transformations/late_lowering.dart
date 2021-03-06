// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart';
import 'package:kernel/core_types.dart';
import 'package:kernel/type_algebra.dart';

bool _shouldLowerVariable(VariableDeclaration node) => node.isLate;

bool _shouldLowerUninitializedVariable(VariableDeclaration node) =>
    _shouldLowerVariable(node) && node.initializer == null;

bool _shouldLowerInitializedVariable(VariableDeclaration node) =>
    _shouldLowerVariable(node) && node.initializer != null;

bool _shouldLowerField(Field node) =>
    node.isLate && node.isStatic && node.initializer == null;

class _Reader {
  final Procedure _procedure;
  final FunctionType _type;
  FunctionType _typeWithoutTypeParameters;

  _Reader(this._procedure) : _type = _procedure.getterType {
    _typeWithoutTypeParameters = _type.withoutTypeParameters;
  }
}

class LateLowering {
  final CoreTypes _coreTypes;

  final _Reader _readLocal;
  final _Reader _readField;
  final _Reader _readInitialized;
  final _Reader _readInitializedFinal;

  // TODO(fishythefish): Remove cells when exiting their scope.
  final Map<VariableDeclaration, VariableDeclaration> _variableCells = {};
  final Map<Field, Field> _fieldCells = {};

  Member _contextMember;

  LateLowering(this._coreTypes)
      : _readLocal = _Reader(_coreTypes.cellReadLocal),
        _readField = _Reader(_coreTypes.cellReadField),
        _readInitialized = _Reader(_coreTypes.initializedCellRead),
        _readInitializedFinal = _Reader(_coreTypes.initializedCellReadFinal);

  void transformAdditionalExports(Library node) {
    List<Reference> additionalExports = node.additionalExports;
    Set<Reference> newExports = {};
    additionalExports.removeWhere((Reference reference) {
      Field cell = _fieldCells[reference.node];
      if (cell == null) return false;
      newExports.add(cell.getterReference);
      return true;
    });
    additionalExports.addAll(newExports);
  }

  ConstructorInvocation _callCellConstructor(int fileOffset) =>
      ConstructorInvocation(_coreTypes.cellConstructor,
          Arguments.empty()..fileOffset = fileOffset)
        ..fileOffset = fileOffset;

  ConstructorInvocation _callInitializedCellConstructor(
          Expression initializer, int fileOffset) =>
      ConstructorInvocation(_coreTypes.initializedCellConstructor,
          Arguments([initializer])..fileOffset = fileOffset)
        ..fileOffset = fileOffset;

  InstanceInvocation _callReader(
      _Reader reader, Expression receiver, DartType type, int fileOffset) {
    Procedure procedure = reader._procedure;
    List<DartType> typeArguments = [type];
    return InstanceInvocation(
        InstanceAccessKind.Instance,
        receiver,
        procedure.name,
        Arguments(const [], types: typeArguments)..fileOffset = fileOffset,
        interfaceTarget: procedure,
        functionType:
            Substitution.fromPairs(reader._type.typeParameters, typeArguments)
                .substituteType(reader._typeWithoutTypeParameters))
      ..fileOffset = fileOffset;
  }

  InstanceSet _callSetter(Procedure _setter, Expression receiver,
          Expression value, int fileOffset) =>
      InstanceSet(InstanceAccessKind.Instance, receiver, _setter.name, value,
          interfaceTarget: _setter)
        ..fileOffset = fileOffset;

  VariableDeclaration _uninitializedVariableCell(VariableDeclaration variable) {
    assert(_shouldLowerUninitializedVariable(variable));
    return _variableCells.putIfAbsent(variable, () {
      int fileOffset = variable.fileOffset;
      return VariableDeclaration(variable.name,
          initializer: _callCellConstructor(fileOffset),
          type: InterfaceType(_coreTypes.cellClass,
              _contextMember.enclosingLibrary.nonNullable),
          isFinal: true)
        ..fileOffset = fileOffset;
    });
  }

  FunctionExpression _initializerClosure(
      Expression initializer, DartType type) {
    int fileOffset = initializer.fileOffset;
    ReturnStatement body = ReturnStatement(initializer)
      ..fileOffset = fileOffset;
    FunctionNode closure = FunctionNode(body, returnType: type)
      ..fileOffset = fileOffset;
    return FunctionExpression(closure)..fileOffset = fileOffset;
  }

  VariableDeclaration _initializedVariableCell(VariableDeclaration variable) {
    assert(_shouldLowerInitializedVariable(variable));
    return _variableCells.putIfAbsent(variable, () {
      int fileOffset = variable.fileOffset;
      return VariableDeclaration(variable.name,
          initializer: _callInitializedCellConstructor(
              _initializerClosure(variable.initializer, variable.type),
              fileOffset),
          type: InterfaceType(_coreTypes.initializedCellClass,
              _contextMember.enclosingLibrary.nonNullable),
          isFinal: true)
        ..fileOffset = fileOffset;
    });
  }

  VariableDeclaration _variableCell(VariableDeclaration variable) {
    assert(_shouldLowerVariable(variable));
    return variable.initializer == null
        ? _uninitializedVariableCell(variable)
        : _initializedVariableCell(variable);
  }

  VariableGet _variableCellAccess(
          VariableDeclaration variable, int fileOffset) =>
      VariableGet(_variableCell(variable))..fileOffset = fileOffset;

  TreeNode transformVariableDeclaration(
      VariableDeclaration node, Member contextMember) {
    _contextMember = contextMember;

    if (!_shouldLowerVariable(node)) return node;

    // A [VariableDeclaration] being used as a statement must be a direct child
    // of a [Block].
    if (node.parent is! Block) return node;

    return _variableCell(node);
  }

  TreeNode transformVariableGet(VariableGet node, Member contextMember) {
    _contextMember = contextMember;

    VariableDeclaration variable = node.variable;
    if (!_shouldLowerVariable(variable)) return node;

    int fileOffset = node.fileOffset;
    VariableGet cell = _variableCellAccess(variable, fileOffset);
    _Reader reader = variable.initializer == null
        ? _readLocal
        : (variable.isFinal ? _readInitializedFinal : _readInitialized);
    return _callReader(
        reader, cell, node.promotedType ?? variable.type, fileOffset);
  }

  TreeNode transformVariableSet(VariableSet node, Member contextMember) {
    _contextMember = contextMember;

    VariableDeclaration variable = node.variable;
    if (!_shouldLowerVariable(variable)) return node;

    int fileOffset = node.fileOffset;
    VariableGet cell = _variableCellAccess(variable, fileOffset);
    Procedure setter = variable.initializer == null
        ? (variable.isFinal
            ? _coreTypes.cellFinalLocalValueSetter
            : _coreTypes.cellValueSetter)
        : (variable.isFinal
            ? _coreTypes.initializedCellFinalValueSetter
            : _coreTypes.initializedCellValueSetter);
    return _callSetter(setter, cell, node.value, fileOffset);
  }

  Field _fieldCell(Field field) {
    assert(_shouldLowerField(field));
    return _fieldCells.putIfAbsent(field, () {
      int fileOffset = field.fileOffset;
      field.getterReference.canonicalName?.unbind();
      field.setterReference?.canonicalName?.unbind();
      return Field.immutable(field.name,
          type: InterfaceType(
              _coreTypes.cellClass, field.enclosingLibrary.nonNullable),
          initializer: _callCellConstructor(fileOffset),
          isFinal: true,
          isStatic: true,
          fileUri: field.fileUri)
        ..fileOffset = fileOffset
        ..isNonNullableByDefault = true;
    });
  }

  StaticGet _fieldCellAccess(Field field, int fileOffset) =>
      StaticGet(_fieldCell(field))..fileOffset = fileOffset;

  TreeNode transformField(Field node, Member contextMember) {
    _contextMember = contextMember;

    if (!_shouldLowerField(node)) return node;

    return _fieldCell(node);
  }

  TreeNode transformStaticGet(StaticGet node, Member contextMember) {
    _contextMember = contextMember;

    Member target = node.target;
    if (target is Field && _shouldLowerField(target)) {
      int fileOffset = node.fileOffset;
      StaticGet cell = _fieldCellAccess(target, fileOffset);
      return _callReader(_readField, cell, target.type, fileOffset);
    } else {
      return node;
    }
  }

  TreeNode transformStaticSet(StaticSet node, Member contextMember) {
    _contextMember = contextMember;

    Member target = node.target;
    if (target is Field && _shouldLowerField(target)) {
      int fileOffset = node.fileOffset;
      StaticGet cell = _fieldCellAccess(target, fileOffset);
      Procedure setter = target.isFinal
          ? _coreTypes.cellFinalFieldValueSetter
          : _coreTypes.cellValueSetter;
      return _callSetter(setter, cell, node.value, fileOffset);
    } else {
      return node;
    }
  }
}
