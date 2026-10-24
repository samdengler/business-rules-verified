/-!
# Parties

The people and systems that act in a rule.  Both structures are placeholders:
the Identity namespace will replace them with its own model.
-/

namespace Rules.Core

/-- A traveller named on an offer or order, identified by a stable passenger
reference. -/
structure Passenger where
  /-- The passenger reference, unique within an offer or order. -/
  id : String
  deriving DecidableEq, Repr, Inhabited

/-- Whoever is making a request: a customer, an agent, or a system.  This is
a placeholder that the Identity namespace will replace. -/
structure Principal where
  /-- The authenticated subject identifier. -/
  subject : String
  deriving DecidableEq, Repr, Inhabited

end Rules.Core
