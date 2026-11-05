import VbmContext.Prompt
/-! The request of one call and the history it comes from: the history exactly as it is, then the tail. The history of the next call is this history plus the reply plus the observation, and the function
that makes it has NO argument for the tail, so a tail can never be retained. The layers of a full request, in order: primary prompt, workspace, typed state, last observation, ephemeral tail. -/
namespace VbmContext

/-- The request of one call: the history, then the tail's segments (the render equation: nothing before, between or inside the history). -/
def request (history tail : List String) : List String := history ++ tail

/-- The history of the next call. Its type has no tail parameter. -/
def advance (history : List String) (reply obs : String) : List String := history ++ [reply, obs]

/-- One call as the loop records it: the reply, the observation, and the tail that was shown (which `historyOf` never reads). -/
structure Call where
  reply : String
  obs : String
  tail : List String

/-- The history after a run of calls from `h0`. -/
def historyOf (h0 : List String) (cs : List Call) : List String := cs.foldl (fun h c => advance h c.reply c.obs) h0

/-- A full request: the primary prompt, the workspace layer, the rendered typed state, the last observation, then the tail. -/
def fullRequest (p : PrimaryPrompt) (workspace state : List String) (obs : String) (tail : List String) : List String :=
  context p workspace (state ++ [obs]) ++ tail

end VbmContext
