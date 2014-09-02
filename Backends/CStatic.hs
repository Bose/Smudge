module Backends.CStatic where

import Backends.Backend (Backend(..))
import Grammars.Smudge (StateMachine(..), State(..), Event(..), SideEffect(..), Happening(..))
import Grammars.C89
import Unparsers.C89 (renderPretty)

import Data.Graph.Inductive.Graph (labNodes)
import System.Console.GetOpt
import System.FilePath (FilePath, dropExtension, (<.>))

data CStaticOption = OutFile FilePath
    deriving (Show, Eq)

stateNameFunction :: StateMachine -> [State] -> FunctionDefinition
stateNameFunction (StateMachine smName) ss =
    Function
    (Just $ fromList [A STATIC, C CONST, B CHAR])
    (Declarator (Just $ POINTER Nothing Nothing)
                $ PDirectDeclarator
                  (IDirectDeclarator $ smMangledName ++ "_name")
                  LEFTPAREN
                  (Just $ Left $ ParameterTypeList
                                 (fromList [ParameterDeclaration (fromList [B $ TypeSpecifier smMangledName])
                                            (Just $ Left $ Declarator Nothing $ IDirectDeclarator "s")])
                                 Nothing)
                  RIGHTPAREN)
    Nothing
    (CompoundStatement
    LEFTCURLY
        (Just $ fromList [Declaration (fromList [C CONST, B CHAR]) Nothing SEMICOLON,
                          Declaration (fromList [C CONST, B INT]) Nothing SEMICOLON])
        (Just $ fromList [JStatement $ RETURN Nothing SEMICOLON])
    RIGHTCURLY)
    where
        smMangledName = mangleIdentifier smName ++ "_State"

stateEnum :: StateMachine -> [State] -> Declaration
stateEnum (StateMachine smName) ss =
    Declaration
    (fromList [A TYPEDEF,
               B (makeEnum smMangledName ssMangled)])
    (Just $ fromList [InitDeclarator (Declarator Nothing (IDirectDeclarator smMangledName)) Nothing])
    SEMICOLON
    where
        smMangledName = mangleIdentifier smName ++ "_State"
        ssMangled = [mangleIdentifier (smName ++ show s) | s <- ss]

makeEnum :: Identifier -> [Identifier] -> TypeSpecifier
makeEnum smName [] = ENUM (Left $ smName)
makeEnum smName ss = 
    ENUM (Right (Quad (Just $ smName)
    LEFTCURLY
    (fromList [Enumerator s Nothing | s <- ss])
    RIGHTCURLY))

instance Backend CStaticOption where
    options = ("c",
               [Option [] ["o"] (ReqArg OutFile "FILE")
                 "The name of the target file if not derived from source file."])
    generate os gs inputName = writeTranslationUnit tu (outputName os)
        where tu = fromList $ graphToCode gs
              graphToCode gs = concat [[(ExternalDeclaration (Right $ stateEnum sm (states g))),
                                        (ExternalDeclaration (Left $ stateNameFunction sm (states g)))]
                                       | (sm, g) <- gs]
              states g = [name | (_, name) <- labNodes g]
              writeTranslationUnit u fp = (writeFile fp (renderPretty u)) >> (return fp)
              getFirstOrDefault :: ([a] -> b) -> b -> [a] -> b
              getFirstOrDefault _ d     [] = d
              getFirstOrDefault f _ (x:xs) = f xs
              outputName ((OutFile f):_) = f
              outputName xs = getFirstOrDefault outputName ((dropExtension inputName) <.> "c") xs