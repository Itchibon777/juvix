module QTT where

open import Prelude

open import Category.Applicative
import Function.Identity.Categorical as IdC
import Data.Maybe.Categorical as MaybeC

private variable m n : ℕ

Var = Fin
private variable x y : Var n

Universe = ℕ
private variable u v : Universe

data Term n : Set
data Elim n : Set
Type = Term
Usage = Term


-- maybe the usage stuff should be elims since their types can always
-- be inferred as 𝓤
-- (and then the bits be renamed to ChkTerm and InfTerm or something i
-- suppose)

data Term n where
  ⋆         : (u : Universe) → Type n
  𝓤         : Type n
  𝚷[_/_]_   : (π : Usage n) (S : Type n) (T : Type (suc n)) → Type n
  𝛌_        : (t : Term (suc n)) → Term n
  0ᵘ ωᵘ     : Usage n
  sucᵘ      : (π   : Usage n) → Usage n
  _+ᵘ_ _*ᵘ_ : (π ρ : Usage n) → Usage n
  [_]       : (e : Elim n) → Term n
infixr 150 𝚷[_/_]_ 𝛌_
infixl 300 _+ᵘ_ ; infixl 310 _*ᵘ_
private variable s t : Term n ; S S′ T T′ : Type n ; π ρ : Usage n

data Elim n where
  `_     : (x : Var n) → Elim n
  _∙_    : (f : Elim n) (s : Term n) → Elim n
  𝓤-elim : (T : Type (suc n)) →
           (z : Term n) (s : Term (suc (suc n))) (w : Term n) →
           (π : Usage n) → Elim n
  _⦂_    : (s : Term n) (S : Type n) → Elim n
infix 1000 `_ ; infixl 400 _∙_ ; infix 100 _⦂_
private variable e f : Elim n

pattern ``_ x = [ ` x ]
infix 1000 ``_


data _⩿_ : Rel (Type n) lzero where
  ⋆    : (uv : u ℕ.≤ v) → ⋆ u ⩿ ⋆ {n} v
  𝚷    : (ss : S′ ⩿ S) (tt : T ⩿ T′) → 𝚷[ π / S ] T ⩿ 𝚷[ π / S′ ] T′
  refl : S ⩿ S
  -- (maybe recurse into other structures?)
infix 4 _⩿_

⩿-At : ∀ n → Rel (Type n) _
⩿-At _ = _⩿_

module _ where
  open Relation

  ⩿-refl : Reflexive $ ⩿-At n
  ⩿-refl = refl

  ⩿-antisym : Antisymmetric _≡_ $ ⩿-At n
  ⩿-antisym (⋆ uv)  (⋆ vu)    = ≡.cong ⋆ (ℕ.≤-antisym uv vu)
  ⩿-antisym (𝚷 s t) (𝚷 s′ t′) = ≡.cong₂ _ (⩿-antisym s′ s) (⩿-antisym t t′)
  ⩿-antisym _       refl      = refl
  ⩿-antisym refl    _         = refl

  ⩿-trans : Transitive $ ⩿-At n
  ⩿-trans (⋆ uv)    (⋆ vw)    = ⋆ (ℕ.≤-trans uv vw)
  ⩿-trans (𝚷 s₁ t₁) (𝚷 s₂ t₂) = 𝚷 (⩿-trans s₂ s₁) (⩿-trans t₁ t₂)
  ⩿-trans A         refl      = A
  ⩿-trans refl      B         = B

  ⩿-isPO : IsPartialOrder _≡_ $ ⩿-At n
  ⩿-isPO =
    record {
      isPreorder = record {
        isEquivalence = ≡.isEquivalence ;
        reflexive = λ{refl → refl} ;
        trans = ⩿-trans
      } ;
      antisym = ⩿-antisym
    }

  ⩿-poset : ℕ → Poset _ _ _
  ⩿-poset n = record { isPartialOrder = ⩿-isPO {n} }

-- weakˣ′ x M inserts an extra bound variable between x - 1 and x
weakᵗ′ : Var (suc n) → Term n → Term (suc n)
weakᵉ′ : Var (suc n) → Elim n → Elim (suc n)
weakᵗ′ x (⋆ u) = ⋆ u
weakᵗ′ x 𝓤 = 𝓤
weakᵗ′ x (𝚷[ π / S ] T) = 𝚷[ weakᵗ′ x π / weakᵗ′ x S ] weakᵗ′ (suc x) T
weakᵗ′ x (𝛌 t) = 𝛌 weakᵗ′ (suc x) t
weakᵗ′ x 0ᵘ = 0ᵘ
weakᵗ′ x ωᵘ = ωᵘ
weakᵗ′ x (sucᵘ π) = sucᵘ (weakᵗ′ x π)
weakᵗ′ x (π +ᵘ ρ) = weakᵗ′ x π +ᵘ weakᵗ′ x ρ
weakᵗ′ x (π *ᵘ ρ) = weakᵗ′ x π *ᵘ weakᵗ′ x ρ
weakᵗ′ x [ e ] = [ weakᵉ′ x e ]
weakᵉ′ x (` y) = ` Fin.punchIn x y
weakᵉ′ x (f ∙ s) = weakᵉ′ x f ∙ weakᵗ′ x s
weakᵉ′ x (s ⦂ S) = weakᵗ′ x s ⦂ weakᵗ′ x S
weakᵉ′ x (𝓤-elim T z s w π) =
  let x′ = suc x ; x″ = suc x′ in
  𝓤-elim (weakᵗ′ x′ T) (weakᵗ′ x z) (weakᵗ′ x″ s) (weakᵗ′ x w) (weakᵗ′ x π)


module _ {F : Set → Set} (A : RawApplicative F) where
  open RawApplicative A
  -- substˣ″ x M e replaces occurrences of variable x in M with the
  -- result of e (and shuffles the remaining indices accordingly)
  substᵗ″ : Var (suc n) → Term (suc n) → F (Elim n) → F (Term n)
  substᵉ″ : Var (suc n) → Elim (suc n) → F (Elim n) → F (Elim n)
  substᵗ″ x (⋆ u) e = pure $ ⋆ u
  substᵗ″ x 𝓤 e = pure 𝓤
  substᵗ″ x (𝚷[ π / S ] T) e =
    pure 𝚷[_/_]_ ⊛ substᵗ″ x π e
                 ⊛ substᵗ″ x S e
                 ⊛ (substᵗ″ (suc x) T (weakᵉ′ x <$> e))
  substᵗ″ x (𝛌 t) e = 𝛌_ <$> substᵗ″ (suc x) t (weakᵉ′ x <$> e)
  substᵗ″ x 0ᵘ e = pure 0ᵘ
  substᵗ″ x ωᵘ e = pure ωᵘ
  substᵗ″ x (sucᵘ π) e = sucᵘ <$> substᵗ″ x π e
  substᵗ″ x (π +ᵘ ρ) e = pure _+ᵘ_ ⊛ substᵗ″ x π e ⊛ substᵗ″ x ρ e
  substᵗ″ x (π *ᵘ ρ) e = pure _*ᵘ_ ⊛ substᵗ″ x π e ⊛ substᵗ″ x ρ e
  substᵗ″ x [ f ] e = [_] <$> substᵉ″ x f e
  substᵉ″ x (` y) e = case x Fin.≟ y of λ where
    (yes _)  → e
    (no x≢y) → pure $ ` Fin.punchOut x≢y
  substᵉ″ x (f ∙ s) e = pure _∙_ ⊛ substᵉ″ x f e ⊛ substᵗ″ x s e
  substᵉ″ x (s ⦂ S) e = pure _⦂_ ⊛ substᵗ″ x s e ⊛ substᵗ″ x S e
  substᵉ″ x (𝓤-elim T z s w π) e =
    let x′ = suc x  ; e′ = weakᵉ′ x  <$> e
        x″ = suc x′ ; e″ = weakᵉ′ x′ <$> e′ in
    pure 𝓤-elim ⊛ substᵗ″ x′ T e′
                ⊛ substᵗ″ x  z e ⊛ substᵗ″ x″ s e″ ⊛ substᵗ″ x w e
                ⊛ substᵗ″ x  π e


module Subst {ℓ} {𝒯 ℰ : ℕ → Set ℓ}
             (weak′   : ∀ {n} → Var (suc n) → 𝒯 n → 𝒯 (suc n))
             (subst″  : ∀ {F} → RawApplicative F → ∀ {n} →
                        Var (suc n) → 𝒯 (suc n) → F (ℰ n) → F (𝒯 n))
 where
  weak : 𝒯 n → 𝒯 (suc n)
  weak = weak′ 0

  subst′ : Var (suc n) → 𝒯 (suc n) → ℰ n → 𝒯 n
  subst′ = subst″ IdC.applicative

  subst : 𝒯 (suc n) → ℰ n → 𝒯 n
  subst = subst′ 0

  chop′ : Var (suc n) → 𝒯 (suc n) → Maybe (𝒯 n)
  chop′ x t = subst″ MaybeC.applicative x t nothing

  chop : 𝒯 (suc n) → Maybe (𝒯 n)
  chop = chop′ 0

open Subst weakᵗ′ substᵗ″ public using ()
  renaming (weak to weakᵗ ; subst′ to substᵗ′ ; subst to substᵗ ;
            chop′ to chopᵗ′ ; chop to chopᵗ)

open Subst weakᵉ′ substᵉ″ public using ()
  renaming (weak to weakᵉ ; subst′ to substᵉ′ ; subst to substᵉ ;
            chop′ to chopᵉ′ ; chop to chopᵉ)


punchIn-≢ : x ≢ Fin.punchIn x y
punchIn-≢ {x = zero}  {y}     ()
punchIn-≢ {x = suc x} {zero}  ()
punchIn-≢ {x = suc x} {suc y} eq = punchIn-≢ $ Fin.suc-injective eq

punchOutIn : (x≢pi : x ≢ Fin.punchIn x y) → Fin.punchOut x≢pi ≡ y
punchOutIn {x = zero}  {y}     _   = refl
punchOutIn {x = suc x} {zero}  _   = refl
punchOutIn {x = suc x} {suc y} ¬eq = ≡.cong suc (punchOutIn (¬eq ∘ ≡.cong suc))

subst-weakᵗ : (s : Term n) (x : Fin (suc n)) (e : Elim n) →
              substᵗ′ x (weakᵗ′ x s) e ≡ s
subst-weakᵉ : (f : Elim n) (x : Fin (suc n)) (e : Elim n) →
              substᵉ′ x (weakᵉ′ x f) e ≡ f
subst-weakᵗ (⋆ u) x e = refl
subst-weakᵗ 𝓤 x e = refl
subst-weakᵗ (𝚷[ π / S ] T) x e
  rewrite subst-weakᵗ π x e
        | subst-weakᵗ S x e
        | subst-weakᵗ T (suc x) (weakᵉ′ x e) = refl
subst-weakᵗ (𝛌 s) x e rewrite subst-weakᵗ s (suc x) (weakᵉ′ x e) = refl
subst-weakᵗ 0ᵘ x e = refl
subst-weakᵗ ωᵘ x e = refl
subst-weakᵗ (sucᵘ π) x e rewrite subst-weakᵗ π x e = refl
subst-weakᵗ (π +ᵘ ρ) x e rewrite subst-weakᵗ π x e | subst-weakᵗ ρ x e = refl
subst-weakᵗ (π *ᵘ ρ) x e rewrite subst-weakᵗ π x e | subst-weakᵗ ρ x e = refl
subst-weakᵗ [ f ] x e rewrite subst-weakᵉ f x e = refl
subst-weakᵉ (` y) x e with x Fin.≟ Fin.punchIn x y
... | yes p = ⊥-elim $ punchIn-≢ p
... | no  x≢pi rewrite punchOutIn x≢pi = refl
subst-weakᵉ (f ∙ s) x e rewrite subst-weakᵉ f x e | subst-weakᵗ s x e = refl
subst-weakᵉ (𝓤-elim T z s w π) x e
  rewrite subst-weakᵗ T (suc x)       (weakᵉ′ x e)
        | subst-weakᵗ z x             e
        | subst-weakᵗ s (suc (suc x)) (weakᵉ′ (suc x) (weakᵉ′ x e))
        | subst-weakᵗ w x             e
        | subst-weakᵗ π x             e = refl
subst-weakᵉ (s ⦂ S) x e rewrite subst-weakᵗ s x e | subst-weakᵗ S x e = refl


instance number-Term : Number (Term n)
number-Term = record { Constraint = λ _ → ⊤ ; fromNat = λ n → fn n } where
  fn : ℕ → Term n
  fn zero    = 0ᵘ
  fn (suc n) = sucᵘ $ fn n
