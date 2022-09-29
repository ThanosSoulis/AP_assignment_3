-- Skeleton file for Boa Parser.

module BoaParser (ParseError, parseString) where

import BoaAST
-- add any other other imports you need

import Text.ParserCombinators.ReadP
import Control.Applicative ((<|>)) -- may use instead of +++ for easier portability to Parsec
import Data.Char (isDigit, isSpace, isLetter, isPrint)

type Parser a = ReadP a   -- may use synomym for easier portability to Parsec
type ParseError = String -- you may replace this

reservedIdents = ["None", "True", "False", "for", "if", "in", "not"]

-- parseString :: String -> Either ParseError Program
-- parseString s  = case [a | (a,t) <- readP_to_S parseProgram s, all isSpace t] of
--               [a] -> Right a
--               [] -> Left "Parsing failed" 
--               _ -> Left "How did it get here ?"

parseString :: String -> Either ParseError Program
parseString s  = case [a | (a,t) <- readP_to_S parseConst s, all isSpace t] of
              [a] -> Right [SExp a]
              [] -> Left "Parsing failed" 
              _ -> Left "How did it get here ?"


parseProgram :: Parser Program
parseProgram = do
                skipWS
                parseStmts

parseStmts :: Parser [Stmt]
parseStmts = do 
                stmt <- parseStmt
                skipWS
                rest <- parseStmts'
                skipWS
                return (stmt:rest)

parseStmts' :: Parser [Stmt]
parseStmts' = do
    satisfy (== ';')
    skipWS
    parseStmts
    <++ return []

-- parseStmts' :: [Stmt] -> Parser [Stmt]
-- parseStmts' prevStmts = do
--                         satisfy(==';')
--                         skipWS
--                         parseStmts' prevStmts
--                         <|>
--                         return prevStmts

parseStmt :: Parser Stmt
parseStmt = do
            ident <- parseIdent
            skipWS
            satisfy(== '=')
            skipWS
            expr <- parseExpr
            skipWS
            return $ SExp expr
            <|> do 
            expr <- parseExpr
            skipWS
            return $ SExp expr

parseIdent :: Parser String
-- parseIdent :: Parser Either VName FName
parseIdent = do
    ident <- munch1 (\x -> isDigit x || isLetter x || x == '_')
    skipWS
    if isDigit (head ident) || ident `elem` reservedIdents then pfail else return ident

parseExpr :: Parser Exp
parseExpr = do
    skipWS          --this should be unneccessary but shouldn't hurt either
    string "not"
    munch1 isSpace  -- munch1 isWhitespace
    parseExpr
    <|> do 
    skipWS
    parseRel


parseRel :: Parser Exp
parseRel = do
            exp <- parseAddNeg
            skipWS
            parseRel' exp

parseRel' :: Exp -> Parser Exp
parseRel' expr = do
                v <- parseAddNeg
                parseRelOper expr v
                <|>
                return expr

parseRelOper :: Exp -> Exp -> Parser Exp
parseRelOper expr1 expr2 = do
                string "=="
                skipWS
                return $ Oper Eq expr1 expr2
                <|> do
                string "!="
                skipWS
                return $ Not $ Oper Eq expr1 expr2
                <|> do
                satisfy (== '<')
                skipWS
                return $ Oper Less expr1 expr2
                <|> do
                satisfy (== '>')
                skipWS
                return $ Oper Greater expr1 expr2
                <|> do
                string "<="
                skipWS
                return $ Not $ Oper Greater expr1 expr2
                <|> do
                string ">="
                skipWS
                return $ Not $ Oper Less expr1 expr2
                <|> do
                string "in"
                skipWS
                return $ Oper In expr1 expr2
                <|> do
                string "not in"
                skipWS
                return $ Not $ Oper In expr1 expr2
parseAddNeg :: Parser Exp
parseAddNeg = undefined

parseConst :: Parser Exp
parseConst = do --maybe <++ instead
    parseStringConst
    <|> do
    parseNumConst
    <|> do
    ident <- parseIdent
    skipWS
    return $ Const (StringVal ident) --temp, fix!
    <|> do
    string "None"
    skipWS
    return $ Const NoneVal
    <|> do
    string "True"
    skipWS
    return $ Const TrueVal
    <|> do
    string "False"
    skipWS
    return $ Const FalseVal
    <|> do
    satisfy (== '(')
    skipWS
    exp <- parseExpr
    skipWS
    satisfy (== ')')
    skipWS
    return exp
    <|> do --fun call syntax
    fname <- parseIdent
    munch1 isSpace
    satisfy (== '(')
    skipWS
    args <- parseExprz
    skipWS
    satisfy (== ')')
    skipWS
    return $ Call fname args
    <|> do --list comp syntax
    satisfy (== '[')
    skipWS
    exp <- parseExpr
    skipWS
    for <- parseForClause --do def
    skipWS
    rest <- parseClausez --do def
    skipWS
    satisfy (== ']')
    skipSpaces
    return $ Compr exp (for:rest)
    <|> do --eval list syntax
    satisfy (== '[')
    skipWS
    exprz <- parseExprz
    skipWS
    satisfy (== ']')
    skipSpaces
    return $ List exprz --temp fix

parseForClause :: Parser CClause
parseForClause = do
    string "for"
    munch1 isSpace --isWhitespace #
    ident <- parseIdent
    skipWS
    string "in"
    munch1 isSpace --isWhitespace #
    exp <- parseExpr
    skipWS
    return $ CCFor ident exp

parseIfClause :: Parser CClause
parseIfClause = do
    string "if"
    munch1 isSpace -- isWhitespace
    exp <- parseExpr
    return $ CCIf exp

parseClausez :: Parser [CClause]
parseClausez = do
    for <- parseForClause
    rest <- parseClausez
    return (for:rest)

parseExprz :: Parser [Exp]
parseExprz = do parseExprs; 
            <++ return []   --doc this

parseExprs :: Parser [Exp]
parseExprs = do
    exp <- parseExpr
    skipWS
    rest <- parseExprs'
    return (exp:rest)

parseExprs' :: Parser [Exp]
parseExprs' = do
    satisfy (== ',')
    skipWS
    parseExprs
    <++ return [] --doc this


-- To be extended,  probably try to consume '#'  and move on from there
skipWS :: Parser ()
skipWS = skipSpaces

parseComments :: Parser ()
parseComments = undefined
        

parseNumConst :: Parser Exp
parseNumConst = do
    satisfy (== '-')
    num <- parseNumConstHelper
    return $ Const (IntVal (-num))
    <|> do
    num <- parseNumConstHelper
    return $ Const (IntVal num)

parseNumConstHelper :: Parser Int
parseNumConstHelper = do
    num <- munch1 isDigit
    skipWS
    case (head num) of
        '0' -> if length num == 1 then return 0 else pfail 
        _  -> return $ read num

parseStringConst :: Parser Exp
parseStringConst = do
    satisfy (== '\'')
    skipWS
    print <- many parseStringInside
    satisfy (== '\'')
    skipWS
    return $ Const (StringVal $ concat $ print)

parseStringInside :: Parser String
parseStringInside = do 
                    c <- satisfy isPrintable
                    return (c:[])
                    <|> do
                    string "\\\n"
                    return ""
                    <|> do
                    string "\n"
                    return "\n"
                    <|> do
                    string "\'"
                    return "\'"
                    <|> do
                    string "\\\\"
                    return "\\"


isPrintable :: Char -> Bool
isPrintable c = ((isPrint c) && (c /= '\'') && (c /= '\\'))

