{-# LANGUAGE OverloadedStrings #-}

import           Control.Exception (evaluate)
import qualified Data.Map          as M
import qualified Data.Text         as T
import           Test.Hspec

import qualified Grammar
import           Lang
import           Lexer

main :: IO ()
main = hspec $ do
  describe "eval" $ do
    describe "constants" $ do
      it "ints" $
        eval emptyEnv (EInt 10) `shouldBe` (VInt 10, [])
      it "doubles" $
        eval emptyEnv (EDouble 10) `shouldBe` (VDouble 10, [])
      it "strings" $
        eval emptyEnv (EString "hello") `shouldBe` (VString "hello", [])
      it "bools" $
        eval emptyEnv (EBool True) `shouldBe` (VBool True, [])
      it "lists" $
        eval emptyEnv (EList TInt [EInt 1, EInt 2])
           `shouldBe` (VList [VInt 1, VInt 2], [])
      it "objects" $
        eval emptyEnv (EObject (M.fromList [("k", EInt 2),("l", EInt 3)]))
           `shouldBe` (VObject (M.fromList [("k", VInt 2),("l", VInt 3)]), [])
    describe "vars, let, lams, and application" $ do
      it "lookup" $
        eval (envFromList [(Var "x", VInt 10)]) (EVar (Var "x"))
          `shouldBe` (VInt 10, [])
      it "applying one argument functions" $
        eval emptyEnv (EApp (ELam [(Var "x", TInt)] TInt (EVar (Var "x"))) [EInt 10])
             `shouldBe` (VInt 10, [])
      it "applying two argument functions" $
        eval emptyEnv (EApp (ELam [(Var "x", TInt), (Var "y", TInt)] TInt (EVar (Var "x"))) [EInt 10, EInt 20])
             `shouldBe` (VInt 10, [])
      it "applying closures" $
        eval (envFromList [(Var "f", VLam emptyEnv [Var "x"] (EVar (Var "x")))])
             (EApp (EVar (Var "f")) [EInt 10])
             `shouldBe` (VInt 10, [])
      it "let binding" $
        eval emptyEnv (ELet (Var "x") (EInt 1) (EVar (Var "x")))
             `shouldBe` (VInt 1, [])
      it "let shadowing existing vars in env" $
        eval (envFromList [(Var "x", VInt 10)])
             (ELet (Var "x") (EInt 1) (EVar (Var "x")))
             `shouldBe` (VInt 1, [])
      it "let shadowing let" $
        eval emptyEnv
             (ELet (Var "x") (EInt 2)
                             (ELet (Var "x") (EInt 1) (EVar (Var "x"))))
             `shouldBe` (VInt 1, [])
      it "let should be recursive" $
         eval emptyEnv
              (ELet (Var "f") (ELam [(Var "x", TList TInt)] TInt
                                    (ECase (EVar (Var "x"))
                                           (EInt 0)
                                           (Var "_")
                                           (Var "rest")
                                           (EPrim
                                              PPlus
                                              [EInt 1,
                                               EApp (EVar (Var "f"))
                                                    [EVar (Var "rest")]])))
                    (EApp (EVar (Var "f")) [EList TInt [EInt 0, EInt 0, EInt 0]]))
              `shouldBe` (VInt 3, [])
    describe "if, case, and dot" $ do
      it "if true" $
        eval emptyEnv (EIf (EBool True) (EInt 1) (EInt 2))
             `shouldBe` (VInt 1, [])
      it "if false" $
        eval emptyEnv (EIf (EBool False) (EInt 1) (EInt 2))
             `shouldBe` (VInt 2, [])
      it "case on empty lists" $
        eval emptyEnv (ECase (EList TInt []) (EInt 1) (Var "h") (Var "t") (EInt 2))
             `shouldBe` (VInt 1, [])
      it "case on non-empty list" $
        eval emptyEnv (ECase (EList TInt [EInt 1]) (EInt 1) (Var "h") (Var "t") (EInt 2))
             `shouldBe` (VInt 2, [])
      it "case on non-empty, using head" $
        eval emptyEnv (ECase (EList TInt [EInt 3]) (EInt 1) (Var "h") (Var "t") (EVar (Var "h")))
             `shouldBe` (VInt 3, [])
      it "case on non-empty, using tail" $
        eval emptyEnv (ECase (EList TInt [EInt 2, EInt 3]) (EInt 1) (Var "h") (Var "t") (EVar (Var "t")))
             `shouldBe` (VList [VInt 3] , [])
      it "dot on object should get field" $
        eval emptyEnv (EDot (EObject (M.fromList [("x", EInt 1)])) "x")
             `shouldBe` (VInt 1, [])
    describe "prims" $ do
      it "+ on ints" $
        eval emptyEnv (EPrim PPlus [EInt 1, EInt 1])
             `shouldBe` (VInt 2, [])
      it "+ on doubles" $
        eval emptyEnv (EPrim PPlus [EDouble 1, EDouble 1])
             `shouldBe` (VDouble 2, [])
      it "+ on strings" $
        eval emptyEnv (EPrim PPlus [EString "a", EString "b"])
             `shouldBe` (VString "ab", [])
      it "* on ints" $
        eval emptyEnv (EPrim PTimes [EInt 2, EInt 3])
             `shouldBe` (VInt 6, [])
      it "* on doubles" $
        eval emptyEnv (EPrim PTimes [EDouble 2, EDouble 3])
             `shouldBe` (VDouble 6, [])
      it "- on ints" $
        eval emptyEnv (EPrim PMinus [EInt 2, EInt 3])
             `shouldBe` (VInt (-1), [])
      it "- on doubles" $
        eval emptyEnv (EPrim PMinus [EDouble 2, EDouble 3])
             `shouldBe` (VDouble (-1), [])
      it "/ on int" $
        eval emptyEnv (EPrim PDivide [EInt 4, EInt 2])
             `shouldBe` (VInt 2, [])
      it "/ on doubles" $
        eval emptyEnv (EPrim PDivide [EDouble 3, EDouble 2])
             `shouldBe` (VDouble 1.5, [])
      it "== on ints" $ do
        eval emptyEnv (EPrim PEquals [EInt 1, EInt 1])
             `shouldBe` (VBool True, [])
        eval emptyEnv (EPrim PEquals [EInt 1, EInt 2])
             `shouldBe` (VBool False, [])
      it "== on doubles" $ do
        eval emptyEnv (EPrim PEquals [EDouble 1, EDouble 1])
             `shouldBe` (VBool True, [])
        eval emptyEnv (EPrim PEquals [EDouble 1, EDouble 2])
             `shouldBe` (VBool False, [])
      it "== on strings" $ do
        eval emptyEnv (EPrim PEquals [EString "a", EString "a"])
             `shouldBe` (VBool True, [])
        eval emptyEnv (EPrim PEquals [EString "", EString "a"])
             `shouldBe` (VBool False, [])
      it "== on lists" $ do
        eval emptyEnv (EPrim PEquals [EList TInt [EInt 1], EList TInt [EInt 1]])
             `shouldBe` (VBool True, [])
        eval emptyEnv (EPrim PEquals [EList TInt [], EList TInt [EInt 1]])
             `shouldBe` (VBool False, [])
      it "== on objects" $ do
        eval emptyEnv (EPrim PEquals [EObject (M.fromList [("x", EInt 1)]), EObject (M.fromList [("x", EInt 1)])])
             `shouldBe` (VBool True, [])
        eval emptyEnv (EPrim PEquals [EObject (M.fromList [("x", EInt 1), ("y", EInt 2)]), EObject (M.fromList [("y", EInt 2), ("x", EInt 1)])])
             `shouldBe` (VBool True, [])
        eval emptyEnv (EPrim PEquals [EObject (M.fromList [("x", EInt 1), ("y", EInt 2)]), EObject (M.fromList [("y", EInt 2)])])
             `shouldBe` (VBool False, [])

    describe "sources" $ do
      it "sources should produce their default values" $
        eval emptyEnv (ESource (ES (Id "1") TInt) (EInt 10))
             `shouldBe` (VInt 10, [VSBase (Id "1") [] (VInt 10)])
      it "should be able to add sources of ints" $
        eval emptyEnv (EPrim PPlus [EInt 1
                                   ,ESource (ES (Id "1") TInt) (EInt 10)])
             `shouldBe` (VInt 11, [VSBase (Id "1") [] (VInt 10)])
  describe "tc" $ do
    describe "constants" $ do
      it "ints" $ tc False emptyTEnv (EInt 1) `shouldBe` TInt
      it "strings" $ tc False emptyTEnv (EString "hello") `shouldBe` TString
      it "bools" $ tc False emptyTEnv (EBool True) `shouldBe` TBool
      it "doubles" $ tc False emptyTEnv (EDouble 1) `shouldBe` TDouble
      it "lists" $
        tc False emptyTEnv (EList TInt [EInt 1, EInt 2])
           `shouldBe` TList TInt
      it "lists should not be hererogeneous" $
         evaluate (tc False emptyTEnv (EList TInt [EInt 1, EDouble 2]))
                  `shouldThrow` anyErrorCall
      it "objects" $
        tc False emptyTEnv (EObject (M.fromList [("k", EInt 2),("l", EInt 3)]))
           `shouldBe` TObject (M.fromList [("k", TInt),("l", TInt)])
    describe "prims" $ do
      describe "+ on ints" $ do
        it "works" $
          tc False emptyTEnv (EPrim PPlus [EInt 1, EInt 10])
             `shouldBe` TInt
        it "doesn't work on more than two arguments" $
          evaluate (tc False emptyTEnv (EPrim PPlus [EInt 1, EInt 1, EInt 2]))
                   `shouldThrow` anyErrorCall
        it "doesn't work on less than two arguments" $
          evaluate (tc False emptyTEnv (EPrim PPlus [EInt 1]))
                   `shouldThrow` anyErrorCall
        it "doesn't work on ints and doubles" $
          evaluate (tc False emptyTEnv (EPrim PPlus [EInt 1, EDouble 1]))
                   `shouldThrow` anyErrorCall
        it "doesn't work on ints and bools" $
          evaluate (tc False emptyTEnv (EPrim PPlus [EInt 1, EBool True]))
                   `shouldThrow` anyErrorCall
        it "doesn't work on ints and strings" $
          evaluate (tc False emptyTEnv (EPrim PPlus [EInt 1, EString "hello"]))
                   `shouldThrow` anyErrorCall
      describe "+ on doubles" $ do
        it "works" $
          tc False emptyTEnv (EPrim PPlus [EDouble 1, EDouble 10])
             `shouldBe` TDouble
        it "doesn't work on bools and doubles" $
          evaluate (tc False emptyTEnv (EPrim PPlus [EBool True, EDouble 10]))
                   `shouldThrow` anyErrorCall
      describe "+ on strings" $ do
        it "works" $
             tc False emptyTEnv (EPrim PPlus [EString "a", EString "b"])
                `shouldBe` TString
        it "doesn't work on strings and ints" $
          evaluate (tc False emptyTEnv (EPrim PPlus [EString "a", EInt 10]))
                   `shouldThrow` anyErrorCall
      describe "- on ints" $ do
        it "works" $
           tc False emptyTEnv (EPrim PMinus [EInt 1, EInt 10])
              `shouldBe` TInt
        it "doesn't work on bools and ints" $
          evaluate (tc False emptyTEnv (EPrim PMinus [EBool True, EInt 10]))
                   `shouldThrow` anyErrorCall
        it "- on less than two arguments" $
           evaluate (tc False emptyTEnv (EPrim PMinus [EInt 1]))
                    `shouldThrow` anyErrorCall
        it "- on more than two arguments" $
           evaluate (tc False emptyTEnv (EPrim PMinus [EInt 1, EInt 1, EInt 1]))
                    `shouldThrow` anyErrorCall
      describe "- on doubles" $ do
        it "works" $
          tc False emptyTEnv (EPrim PMinus [EDouble 1, EDouble 10])
             `shouldBe` TDouble
        it "doesn't work on doubles and ints" $
          evaluate (tc False emptyTEnv (EPrim PMinus [EDouble 1, EInt 10]))
                   `shouldThrow` anyErrorCall
      describe "* on ints" $ do
        it "works" $
          tc False emptyTEnv (EPrim PTimes [EInt 1, EInt 10])
             `shouldBe` TInt
        it "doesn't work on doubles and ints" $
          evaluate (tc False emptyTEnv (EPrim PTimes [EDouble 1, EInt 10]))
                   `shouldThrow` anyErrorCall
      describe "* on doubles" $ do
        it "works" $
          tc False emptyTEnv (EPrim PTimes [EDouble 1, EDouble 10])
             `shouldBe` TDouble
        it "doesn't work on doubles and ints" $
          evaluate (tc False emptyTEnv (EPrim PTimes [EDouble 1, EInt 10]))
                   `shouldThrow` anyErrorCall
      describe "/ on ints" $ do
        it "works" $
          tc False emptyTEnv (EPrim PDivide [EInt 1, EInt 10])
             `shouldBe` TInt
        it "doesn't work on doubles and ints" $
          evaluate (tc False emptyTEnv (EPrim PDivide [EDouble 1, EInt 10]))
                   `shouldThrow` anyErrorCall
      describe "/ on doubles" $ do
        it "works" $
          tc False emptyTEnv (EPrim PDivide [EDouble 1, EDouble 10])
             `shouldBe` TDouble
        it "doesn't work on doubles and ints" $
          evaluate (tc False emptyTEnv (EPrim PDivide [EDouble 1, EInt 10]))
                   `shouldThrow` anyErrorCall
      describe "== on ints" $ do
        it "works" $
          tc False emptyTEnv (EPrim PEquals [EInt 1, EInt 10])
             `shouldBe` TBool
        it "doesn't work on doubles and ints" $
          evaluate (tc False emptyTEnv (EPrim PEquals [EDouble 1, EInt 10]))
                   `shouldThrow` anyErrorCall
      describe "== on doubles" $ do
        it "works" $
          tc False emptyTEnv (EPrim PEquals [EDouble 1, EDouble 10])
             `shouldBe` TBool
        it "doesn't work on doubles and ints" $
          evaluate (tc False emptyTEnv (EPrim PEquals [EDouble 1, EInt 10]))
                   `shouldThrow` anyErrorCall
      describe "== on strings" $ do
        it "works" $
          tc False emptyTEnv (EPrim PEquals [EString "", EString "bla"])
             `shouldBe` TBool
        it "doesn't work on strings and ints" $
          evaluate (tc False emptyTEnv (EPrim PEquals [EString "1", EInt 1]))
                   `shouldThrow` anyErrorCall
      describe "== on lists" $ do
        it "works" $
          tc False emptyTEnv (EPrim PEquals [EList TInt [], EList TInt []])
             `shouldBe` TBool
        it "doesn't work on lists of different types" $
          evaluate (tc False emptyTEnv (EPrim PEquals [EList TInt [], EList TString []]))
                   `shouldThrow` anyErrorCall
      describe "== on objects" $ do
        it "works" $
          tc False emptyTEnv (EPrim PEquals [EObject $ M.fromList [("x", EInt 1)], EObject $ M.fromList [("x", EInt 2)]])
             `shouldBe` TBool
        it "doesn't work on fields of different types" $
          evaluate (tc False emptyTEnv (EPrim PEquals [EObject $ M.fromList [("x", EInt 1)], EObject $ M.fromList [("x", EDouble 2)]]))
                   `shouldThrow` anyErrorCall
        it "doesn't work on different fields" $ do
          evaluate (tc False emptyTEnv (EPrim PEquals [EObject $ M.fromList [("x", EInt 1)], EObject $ M.fromList [("y", EInt 2)]]))
                   `shouldThrow` anyErrorCall
          evaluate (tc False emptyTEnv (EPrim PEquals [EObject $ M.fromList [("x", EInt 1)], EObject $ M.fromList [("x", EInt 1), ("y", EInt 2)]]))
                   `shouldThrow` anyErrorCall
          evaluate (tc False emptyTEnv (EPrim PEquals [EObject $ M.fromList [("y", EInt 2), ("x", EInt 1)], EObject $ M.fromList [("y", EInt 2)]]))
                   `shouldThrow` anyErrorCall
      describe "== on bools" $ do
        it "works" $
          tc False emptyTEnv (EPrim PEquals [EBool True, EBool False])
             `shouldBe` TBool
        it "doesn't work on bools and ints" $
          evaluate (tc False emptyTEnv (EPrim PEquals [EBool True, EInt 1]))
                   `shouldThrow` anyErrorCall
    describe "vars, let, lam, and application" $ do
      it "(x:int) : int { x } typechecks" $
        tc False emptyTEnv (ELam [(Var "x", TInt)] TInt (EVar (Var "x")))
           `shouldBe` TLam [TInt] TInt
      it "(x:int) : int { x x } fails" $
        evaluate (tc False emptyTEnv (ELam [(Var "x", TInt)] TInt (EApp (EVar (Var "x"))  [(EVar (Var "x"))])))
                 `shouldThrow` anyErrorCall
      it "(x:int) : int{ 10 } typechecks" $
        tc False emptyTEnv (ELam [(Var "x", TInt)] TInt (EInt 10))
           `shouldBe` TLam [TInt] TInt
      it "(f : int -> int) : int { f 10 } typechecks" $
        tc False emptyTEnv (ELam [(Var "f", TLam [TInt] TInt)] TInt (EApp (EVar (Var "f")) [EInt 10]))
           `shouldBe` TLam [TLam [TInt] TInt] TInt
      it "(x:int y:bool) : bool { y } typechecks" $
        tc False emptyTEnv (ELam [(Var "x", TInt),(Var "y", TBool)] TBool
                           (EVar (Var "y")))
           `shouldBe` TLam [TInt, TBool] TBool
      it "(f : int -> bool) : bool { f true } fails" $
        evaluate (tc False emptyTEnv (ELam [(Var "f", TLam [TInt] TBool)] TBool (EApp (EVar (Var "f")) [EBool True])))
                   `shouldThrow` anyErrorCall
      it "x = 2 in x" $
        tc False emptyTEnv (ELet (Var "x") (EInt 2) (EVar (Var "x")))
           `shouldBe` TInt
      it "x = 2 in x = true in x" $
        tc False emptyTEnv (ELet (Var "x") (EInt 2) (ELet (Var "x") (EBool True) (EVar (Var "x"))))
           `shouldBe` TBool
      it "recursive functions type check" $
        tc False emptyTEnv (ELet (Var "f") (ELam [(Var "x", TList TInt)] TInt
                                    (ECase (EVar (Var "x"))
                                           (EInt 0)
                                           (Var "_")
                                           (Var "rest")
                                           (EPrim
                                              PPlus
                                              [EInt 1,
                                               EApp (EVar (Var "f"))
                                                    [EVar (Var "rest")]])))
                    (EApp (EVar (Var "f")) [EList TInt [EInt 0, EInt 0, EInt 0]]))
          `shouldBe` TInt
    describe "if, dot, and case" $ do
      it "if true 1 2 typechecks" $
        tc False emptyTEnv (EIf (EBool True) (EInt 1) (EInt 2))
           `shouldBe` TInt
      it "if false 1 true fails" $
        evaluate (tc False emptyTEnv (EIf (EBool False) (EInt 1) (EBool True)))
                 `shouldThrow` anyErrorCall
      it "if 1 1 1 fails" $
        evaluate (tc False emptyTEnv (EIf (EInt 1) (EInt 1) (EInt 1)))
                 `shouldThrow` anyErrorCall
      it "if true (x : int) { 10 } (y : int) { 20 } typechecks" $
        tc False emptyTEnv (EIf (EBool True) (ELam [(Var "x", TInt)] TInt (EInt 10)) (ELam [(Var "y", TInt)] TInt (EInt 20)))
           `shouldBe` TLam [TInt] TInt
      it "{x: 1}.x typechecks" $
         tc False emptyTEnv (EDot (EObject (M.fromList [("x", EInt 1)])) "x")
            `shouldBe` TInt
      it "{x: 1}.y fails" $
         evaluate (tc False emptyTEnv (EDot (EObject (M.fromList [("x", EInt 1)])) "y"))
                  `shouldThrow` anyErrorCall
      it "case [:int] { 1 } (_ _) { 2 } typechecks" $
        tc False emptyTEnv (ECase (EList TInt []) (EInt 1) (Var "_") (Var "_") (EInt 2))
           `shouldBe` TInt
      it "case [:int] { true } (_ _) { 2 } fails" $
        evaluate (tc False emptyTEnv (ECase (EList TInt []) (EBool True) (Var "_") (Var "_") (EInt 2)))
                 `shouldThrow` anyErrorCall
      it "case [:int] { true } (h _) { h } fails" $
        evaluate (tc False emptyTEnv (ECase (EList TInt []) (EBool True) (Var "h") (Var "_") (EVar (Var "h"))))
                 `shouldThrow` anyErrorCall
      it "case [:int] { 1 } (h _) { h } typechecks" $
        tc False emptyTEnv (ECase (EList TInt []) (EInt 1) (Var "h") (Var "_") (EVar (Var "h")))
                                                                                       `shouldBe` TInt
      it "case [:int] { 1 } (_ t) { t } fails" $
        evaluate (tc False emptyTEnv (ECase (EList TInt []) (EInt 1) (Var "_") (Var "t") (EVar (Var "t"))))
                 `shouldThrow` anyErrorCall
    describe "sources" $ do
      it "source<foo;int;1> typechecks" $
        tc False emptyTEnv (ESource (ES (Id "foo") TInt) (EInt 1))
           `shouldBe` TInt
      it "source<foo;[int];[1,2,3 : int]> typechecks" $
        tc False emptyTEnv (ESource (ES (Id "foo") (TList TInt)) (EList TInt [EInt 1, EInt 2, EInt 3]))
           `shouldBe` TList TInt
      it "source<foo;int;\"too\"> fails" $
        evaluate (tc False emptyTEnv (ESource (ES (Id "foo") TInt) (EString "too")))
                 `shouldThrow` anyErrorCall
      it "source<foo; int -> int; (x : int) { x }> fails" $
        evaluate (tc False emptyTEnv (ESource (ES (Id "foo") (TLam [TInt] TInt)) (ELam [(Var "x", TInt)] TInt (EVar (Var "x")))))
                 `shouldThrow` anyErrorCall
      it "source<foo; { x : int -> int }; {x: (y : int) { y } }> fails" $
        evaluate (tc False emptyTEnv (ESource (ES (Id "foo") (TObject (M.fromList [("x", TLam [TInt] TInt)]))) (EObject (M.fromList [("x", ELam [(Var "x", TInt)] TInt (EVar (Var "x")))]))))
                 `shouldThrow` anyErrorCall
  describe "parsing expr" $ do
    let shouldParse s v = it s $ Grammar.parse (lexer s) `shouldBe` v
    "1" `shouldParse` EInt 1
    "012345" `shouldParse` EInt 12345
    "1.0" `shouldParse` EDouble 1.0
    "100.05" `shouldParse` EDouble 100.05
    "true" `shouldParse` EBool True
    "false" `shouldParse` EBool False
    "\"blah\"" `shouldParse` EString "blah"
    "\"true\"" `shouldParse` EString "true"
    "[:int]" `shouldParse` EList TInt []
    "[ : int]" `shouldParse` EList TInt []
    "[0 : int ]" `shouldParse` EList TInt [EInt 0]
    "[0, 1 ,2:int]" `shouldParse` EList TInt [EInt 0
                                           ,EInt 1
                                           ,EInt 2]
    "[[:int]:[int]]" `shouldParse` EList (TList TInt) [EList TInt []]
    "x" `shouldParse` EVar (Var "x")
    "x1_z" `shouldParse` EVar (Var "x1_z")
    "x1-z" `shouldParse` EVar (Var "x1-z")
    "a'" `shouldParse` EVar (Var "a'")
    "(x : int) : int { x }" `shouldParse` ELam [(Var "x", TInt)] TInt
                                         (EVar (Var "x"))
    "(x : int, y : string) : int { x }" `shouldParse` ELam [(Var "x", TInt), (Var "y", TString)] TInt
                                                  (EVar (Var "x"))
    "() : int { 1 }" `shouldParse` ELam [] TInt (EInt 1)
    "x()" `shouldParse` EApp (EVar (Var "x")) []
    "x(1,2,3)" `shouldParse` EApp (EVar (Var "x")) [EInt 1
                                                   ,EInt 2
                                                   ,EInt 3]
    "() : int {1} ()" `shouldParse` EApp (ELam [] TInt (EInt 1)) []
    "(x : -> int) : int {x()} (() : int { 1})" `shouldParse` EApp (ELam [(Var "x", TLam [] TInt )] TInt (EApp (EVar (Var "x")) [])) [ELam [] TInt (EInt 1)]
    "{x: 1, y: 2}" `shouldParse` EObject (M.fromList [("x", EInt 1), ("y", EInt 2)])
    "{x: 1}" `shouldParse` EObject (M.fromList [("x", EInt 1)])
    "{}" `shouldParse` EObject M.empty
    "if true { 1 } else { 2 }" `shouldParse` EIf (EBool True) (EInt 1) (EInt 2)
    "if () : bool { true } () { 1 } else { 2 }" `shouldParse` EIf (EApp (ELam [] TBool (EBool True)) []) (EInt 1) (EInt 2)
    "case [:int] { 1 } (_ _) { 2 }" `shouldParse` (ECase (EList TInt []) (EInt 1) (Var "_") (Var "_") (EInt 2))
    "case [3 : int] { 1 } (h t) { h }" `shouldParse` (ECase (EList TInt [EInt 3]) (EInt 1) (Var "h") (Var "t") (EVar (Var "h")))
    "x.y" `shouldParse` (EDot (EVar (Var "x")) "y")
    "{y: 1}.y" `shouldParse` (EDot (EObject (M.fromList [("y", EInt 1)])) "y")
    "x = 2 in x" `shouldParse` (ELet (Var "x") (EInt 2) (EVar (Var "x")))
    "x = y = 0 in 10 in x" `shouldParse` (ELet (Var "x") (ELet (Var "y") (EInt 0) (EInt 10)) (EVar (Var "x")))
    "1 + 2" `shouldParse` (EPrim PPlus [EInt 1, EInt 2])
    "1 + 2 + 3" `shouldParse` (EPrim PPlus [EPrim PPlus [EInt 1, EInt 2], EInt 3])
    "1 + (2 + 3)" `shouldParse` (EPrim PPlus [EInt 1, EPrim PPlus [EInt 2, EInt 3]])
    "1 * 2" `shouldParse` (EPrim PTimes [EInt 1, EInt 2])
    "1 - 2" `shouldParse` (EPrim PMinus [EInt 1, EInt 2])
    "1 - 2 - 3" `shouldParse` (EPrim PMinus [EPrim PMinus [EInt 1, EInt 2], EInt 3])
    "1 - 2 * 3" `shouldParse` (EPrim PMinus [EInt 1, EPrim PTimes [EInt 2, EInt 3]])
    "(1 - 2) * 3" `shouldParse` (EPrim PTimes [EPrim PMinus [EInt 1, EInt 2], EInt 3])
    "1 / 2" `shouldParse` (EPrim PDivide [EInt 1, EInt 2])
    "1 + 2 / 3" `shouldParse` (EPrim PPlus [EInt 1, EPrim PDivide [EInt 2, EInt 3]])
    "0 - 1 + 2 / 3" `shouldParse` (EPrim PPlus [EPrim PMinus [EInt 0, EInt 1],EPrim PDivide [EInt 2, EInt 3]])
    "1 == 2" `shouldParse` (EPrim PEquals [EInt 1, EInt 2])
    "1 + 1 == 2" `shouldParse` (EPrim PEquals [EPrim PPlus [EInt 1, EInt 1], EInt 2])
    "1 + 1 == 2 * 1" `shouldParse` (EPrim PEquals [EPrim PPlus [EInt 1, EInt 1], EPrim PTimes [EInt 2, EInt 1]])
    "1 + 1 * 2 == 2 - 1" `shouldParse` (EPrim PEquals [EPrim PPlus [EInt 1, EPrim PTimes [EInt 1, EInt 2]], EPrim PMinus [EInt 2, EInt 1]])
    "source<foo;[int];[1,2,3 : int]>" `shouldParse` (ESource (ES (Id "foo") (TList TInt)) (EList TInt [EInt 1, EInt 2, EInt 3]))
    "x = 10 y = 20 in y" `shouldParse` (ELet (Var "x") (EInt 10) (ELet (Var "y") (EInt 20) (EVar (Var "y"))))
  -- describe "parsing typ" $ do
  --   let shouldParse s v = it (T.unpack s) $ parseT s `shouldBe` Right v
  --   "int" `shouldParse` TInt
  --   "string" `shouldParse` TString
  --   "[int]" `shouldParse` TList TInt
  --   "int -> int" `shouldParse` TLam [TInt] TInt
  --   "-> int" `shouldParse` TLam [] TInt
  --   "int, string -> int" `shouldParse` TLam [TInt, TString] TInt
