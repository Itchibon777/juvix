module Juvix.Core.Translate where

import qualified Juvix.Core.HR as HR
import qualified Juvix.Core.IR as IR
import Juvix.Core.Utility
import Juvix.Library

-- contract: no shadowing
-- TODO - handle this automatically by renaming shadowed vars
hrToIR ∷ HR.Term primTy primVal → IR.Term primTy primVal
hrToIR = fst . exec . hrToIR'

hrToIR' ∷
  (HasState "symbolStack" [Symbol] m) ⇒
  HR.Term primTy primVal →
  m (IR.Term primTy primVal)
hrToIR' term =
  case term of
    HR.Star n → pure (IR.Star n)
    HR.PrimTy p → pure (IR.PrimTy p)
    HR.Pi u a b → do
      a ← hrToIR' a
      b ← hrToIR' b
      pure (IR.Pi u a b)
    HR.Lam n b → do
      pushName n
      b ← hrToIR' b
      pure (IR.Lam b)
    HR.Elim e → IR.Elim |<< hrElimToIR' e

hrElimToIR' ∷
  (HasState "symbolStack" [Symbol] m) ⇒
  HR.Elim primTy primVal →
  m (IR.Elim primTy primVal)
hrElimToIR' elim =
  case elim of
    HR.Var n → do
      maybeIndex ← lookupName n
      pure $ case maybeIndex of
        Just ind → IR.Bound (fromIntegral ind)
        Nothing → IR.Free (IR.Global (show n))
    HR.Prim p → pure (IR.Prim p)
    HR.App f x → do
      f ← hrElimToIR' f
      x ← hrToIR' x
      pure (IR.App f x)
    HR.Ann u t x → do
      t ← hrToIR' t
      x ← hrToIR' x
      pure (IR.Ann u t x)

irToHR ∷ IR.Term primTy primVal → HR.Term primTy primVal
irToHR = fst . exec . irToHR'

irToHR' ∷
  ( HasState "nextName" Int m,
    HasState "nameStack" [Int] m
  ) ⇒
  IR.Term primTy primVal →
  m (HR.Term primTy primVal)
irToHR' term =
  case term of
    IR.Star n → pure (HR.Star n)
    IR.PrimTy p → pure (HR.PrimTy p)
    IR.Pi u a b → do
      a ← irToHR' a
      b ← irToHR' b
      pure (HR.Pi u a b)
    IR.Lam t → do
      n ← newName
      t ← irToHR' t
      pure (HR.Lam n t)
    IR.Elim e → HR.Elim |<< irElimToHR' e

irElimToHR' ∷
  ( HasState "nextName" Int m,
    HasState "nameStack" [Int] m
  ) ⇒
  IR.Elim primTy primVal →
  m (HR.Elim primTy primVal)
irElimToHR' elim =
  case elim of
    IR.Free n → pure (HR.Var (intern (show n)))
    IR.Bound i → do
      v ← unDeBruijin (fromIntegral i)
      pure (HR.Var v)
    IR.Prim p → pure (HR.Prim p)
    IR.App f x → do
      f ← irElimToHR' f
      x ← irToHR' x
      pure (HR.App f x)
    IR.Ann u t x → do
      t ← irToHR' t
      x ← irToHR' x
      pure (HR.Ann u t x)

exec ∷ EnvElim a → (a, Env)
exec (EnvCon env) = runState env (Env 0 [] [])

data Env
  = Env
      { nextName ∷ Int,
        nameStack ∷ [Int],
        symbolStack ∷ [Symbol]
      }
  deriving (Show, Eq, Generic)

newtype EnvElim a = EnvCon (State Env a)
  deriving (Functor, Applicative, Monad)
  deriving
    (HasState "nextName" Int)
    via Field "nextName" () (MonadState (State Env))
  deriving
    (HasState "nameStack" [Int])
    via Field "nameStack" () (MonadState (State Env))
  deriving
    (HasState "symbolStack" [Symbol])
    via Field "symbolStack" () (MonadState (State Env))
