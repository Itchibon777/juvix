open import Usage as U

module QTT {ℓʲ ℓʲ′ ℓᵗ ℓᵗ′ ℓᵗ″} (usages : Usages ℓʲ ℓʲ′ ℓᵗ ℓᵗ′ ℓᵗ″) where

open import Prelude

private variable m n : ℕ

open module Usage = Usages usages public
  using (Usageʲ ; Usageᵗ ; ⟦_⟧ ;
         _+_ ; _*_ ; 0# ; 0#ᵗ ; 1# ; 1#ᵗ ;
         _≈ʲ_ ; _≟ʲ_ ; _≈ᵗ_ ; _≟ᵗ_ ; _≾ᵗ_ ; _≾ᵗ?_)
private variable π π′ ρ ρ′ ζ : Usageᵗ ; σ σ′ : Usageʲ
-- ζ stands for usages which should be zero

Var = Fin
private variable x y : Var n

Universe = ℕ
private variable u v : Universe

data Term n : Set ℓᵗ
data Elim n : Set ℓᵗ
Type = Term


data Term n where
  sort : (u : Universe) → Type n
  Π[_/_]_ : (π : Usageᵗ) (S : Type n) (T : Type (suc n)) → Type n
  Λ_   : (t : Term (suc n)) → Term n
  [_]  : (e : Elim n) → Term n
infixr 150 Π[_/_]_ Λ_
private variable s s′ t t′ : Term n ; S S′ T T′ R R′ : Type n

data Elim n where
  `_  : (x : Var n) → Elim n
  _∙_ : (f : Elim n) (s : Term n) → Elim n
  _⦂_ : (s : Term n) (S : Type n) → Elim n
infix 1000 `_ ; infixl 200 _∙_ ; infix 100 _⦂_
private variable e e′ f f′ : Elim n


data _⩿_ : Rel (Type n) lzero where
  sort : u ℕ.≤ v → sort u ⩿ sort {n} v
  Π    : S′ ⩿ S → T ⩿ T′ → Π[ π / S ] T ⩿ Π[ π / S′ ] T′
  refl : S ⩿ S
  -- (maybe recurse into other structures?)
infix 4 _⩿_

weakᵗ′ : Var (suc n) → Term n → Term (suc n)
weakᵉ′ : Var (suc n) → Elim n → Elim (suc n)
weakᵗ′ i (sort u)  = sort u
weakᵗ′ i (Π[ π / S ] T) = Π[ π / weakᵗ′ i S ] weakᵗ′ (suc i) T
weakᵗ′ i (Λ t)     = Λ weakᵗ′ (suc i) t
weakᵗ′ i [ e ]     = [ weakᵉ′ i e ]
weakᵉ′ i (` x)     = ` Fin.punchIn i x
weakᵉ′ i (f ∙ s)   = weakᵉ′ i f ∙ weakᵗ′ i s
weakᵉ′ i (s ⦂ S)   = weakᵗ′ i s ⦂ weakᵗ′ i S

weakᵗ : Term n → Term (suc n)
weakᵗ = weakᵗ′ zero
weakᵉ : Elim n → Elim (suc n)
weakᵉ = weakᵉ′ zero

substᵗ′ : Var (suc n) → Term (suc n) → Elim n → Term n
substᵉ′ : Var (suc n) → Elim (suc n) → Elim n → Elim n
substᵗ′ i (sort u) e = sort u
substᵗ′ i (Π[ π / S ] T) e =
  Π[ π / substᵗ′ i S e ] substᵗ′ (suc i) T (weakᵉ′ i e)
substᵗ′ i (Λ t) e = Λ substᵗ′ (suc i) t (weakᵉ′ i e)
substᵗ′ i [ f ] e = [ substᵉ′ i f e ]
substᵉ′ i (` x) e =
  case i Fin.≟ x of λ{(yes _) → e ; (no i≢x) → ` Fin.punchOut i≢x}
substᵉ′ i (f ∙ s) e = substᵉ′ i f e ∙ substᵗ′ i s e
substᵉ′ i (s ⦂ S) e = substᵗ′ i s e ⦂ substᵗ′ i S e

substᵗ : Term (suc n) → Elim n → Term n
substᵗ = substᵗ′ zero
substᵉ : Elim (suc n) → Elim n → Elim n
substᵉ = substᵉ′ zero



-- allows using de Bruijn indices as terms/elims
module _ where
  open Number

  instance number-Elim : ∀ {n} → Number (Elim n)
  number-Elim {n} = λ where
    .Constraint x → Lift _ $ Fin.number {n} .Constraint x
    .fromNat n    → ` Fin.number .fromNat n

  instance number-Term : ∀ {n} → Number (Term n)
  number-Term {n} = λ where
    .Constraint      → number-Elim {n} .Constraint
    .fromNat n ⦃ x ⦄ → [ number-Elim .fromNat n ⦃ x ⦄ ]
