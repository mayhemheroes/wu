use std::rc::Rc;

use super::*;

#[derive(Debug, Clone, PartialEq)]
pub enum StatementNode<'s> {
  Expression(Expression<'s>)
}

#[derive(Debug, Clone, PartialEq)]
pub struct Statement<'s> {
  pub node: StatementNode<'s>,
  pub pos:  TokenElement<'s>,
}

impl<'s> Statement<'s> {
  pub fn new(node: StatementNode<'s>, pos: TokenElement<'s>) -> Self {
    Statement {
      node,
      pos,
    }
  }
}


#[derive(Debug, Clone, PartialEq)]
pub enum ExpressionNode<'e> {
  Number(f64),
  String(String),
  Char(char),
  Bool(bool),
  Identifier(String),
  Binary(Rc<Expression<'e>>, Operator, Rc<Expression<'e>>),
  Unary(Operator, Rc<Expression<'e>>),
  EOF,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Expression<'e> {
  pub node: ExpressionNode<'e>,
  pub pos:  TokenElement<'e>,
}

impl<'e> Expression<'e> {
  pub fn new(node: ExpressionNode<'e>, pos: TokenElement<'e>) -> Self {
    Expression {
      node,
      pos,
    }
  }
}



#[derive(Debug, Clone, PartialEq)]
pub enum Operator {
  Add, Sub, Mul, Div, Mod, Pow, Concat,
}

impl Operator {
  pub fn from_str(operator: &str) -> Option<(Operator, u8)> {
    use self::Operator::*;

    let op_prec = match operator {
      "+"  => (Add,    0),
      "-"  => (Sub,    0),
      "++" => (Concat, 0),
      "*"  => (Mul,    1),
      "/"  => (Div,    1),
      "%"  => (Mod,    1),
      "^"  => (Pow,    2),
      _    => return None,
    };

    Some(op_prec)
  }
}