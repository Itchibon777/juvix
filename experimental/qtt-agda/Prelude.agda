module Prelude where

open import Agda.Primitive public using (Level ; lzero ; lsuc ; _⊔_)
open import Agda.Builtin.FromNat public

-- like the one from stdlib but with more instance
record Lift {a} ℓ (A : Set a) : Set (a ⊔ ℓ) where
  instance constructor lift
  field ⦃ lower ⦄ : A

open import Function public

module ⊤ where
  open import Data.Unit public hiding (module ⊤)
open ⊤ public using (⊤ ; tt)

module ⊥ where
  open import Data.Empty public hiding (module ⊥)
open ⊥ public using (⊥ ; ⊥-elim)


module ℕ where
  open import Data.Nat public hiding (module ℕ)
  open import Data.Nat.Properties public
  import Data.Nat.Literals as Lit

  instance number = Lit.number
open ℕ public using (ℕ ; zero ; suc)


module Fin where
  open import Data.Fin public hiding (module Fin)
  open import Data.Fin.Properties public
  import Data.Fin.Literals as Lit

  instance number : ∀ {n} → Number (Fin n)
  number = Lit.number _
open Fin public using (Fin ; zero ; suc ; #_)


module ⊎ where
  open import Data.Sum public hiding (module _⊎_)
  open import Data.Sum.Properties public
open ⊎ public using (_⊎_ ; inj₁ ; inj₂)

module Σ where
  open import Data.Product public hiding (module Σ)
open Σ public using (Σ ; Σ-syntax ; _×_ ; ∃ ; _,_ ; -,_)


module Maybe where
  open import Data.Maybe public hiding (module Maybe)
  open import Data.Maybe.Properties public
open Maybe public using (Maybe ; nothing ; just)

module Bool where
  open import Data.Bool public hiding (module Bool)
  open import Data.Bool.Properties public
open Bool public using (Bool ; true ; false ; if_then_else_)

module Relation where
  open import Relation.Nullary public
  open import Relation.Nullary.Decidable public
  open import Relation.Binary public hiding (Irrelevant)
open Relation public
  using (Rel ; Dec ; yes ; no ; Decidable ; ¬_ ; True ; False ; ⌊_⌋)

module Algebra where
  open import Algebra public
  open import Algebra.FunctionProperties.Core public

  import Algebra.Structures as S
  import Algebra.FunctionProperties as F

  module Generic where
    open S public ; open F public hiding (Op₁ ; Op₂)
  module WithEq {a ℓ} {A : Set a} (≈ : Rel A ℓ) where
    open S ≈ public ; open F ≈ public hiding (Op₁ ; Op₂)
open Algebra public using (Op₁ ; Op₂)

module ≡ where
  open import Relation.Binary.PropositionalEquality public hiding (module _≡_)

  At : ∀ {a} (A : Set a) → Rel A _
  At A = _≡_ {A = A}
open ≡ public using (_≡_ ; refl) renaming (At to ≡-At)
