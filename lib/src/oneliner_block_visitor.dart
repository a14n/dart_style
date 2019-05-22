// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'source_visitor.dart';

/// Helper class for [SourceVisitor] that checks if a block can be one line.
class OneLinerBlockVisitor extends GeneralizingAstVisitor<bool> {
  OneLinerBlockVisitor._();

  @override
  bool visitBlock(Block node) {
    return false;
  }

  @override
  bool visitExpressionFunctionBody(ExpressionFunctionBody node) {
    return false;
  }

  @override
  bool visitReturnStatement(ReturnStatement node) {
    return false;
  }

  @override
  bool visitYieldStatement(YieldStatement node) {
    return false;
  }

  static bool isOneLiner(Block node) {
    if (node.statements.length != 1 ||
        node.statements.first.beginToken.precedingComments != null ||
        node.rightBracket.precedingComments != null) return false;
    var parent = node.parent;
    if (parent is! BlockFunctionBody) return false;

    var container = parent?.parent?.parent;
    var statement = node.statements.first;

    // we allow only some elements that add indentation (otherwise it doesn't work correctly when statement is splitted)
    bool isAllowed = false;
    if (container is MethodDeclaration ||
        container is AssignmentExpression ||
        container is VariableDeclaration) {
      isAllowed = true;
      return statement.accept(OneLinerBlockVisitor._()) ?? true;
    } else {
      if (container is NamedExpression) container = container?.parent;
      if (container is ArgumentList &&
          container.arguments.last.endToken.next.type == TokenType.COMMA) {
        isAllowed = true;
      }
    }

    return isAllowed && (statement.accept(OneLinerBlockVisitor._()) ?? true);
  }
}
