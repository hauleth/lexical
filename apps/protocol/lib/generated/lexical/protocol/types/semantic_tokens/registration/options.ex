# This file's contents are auto-generated. Do not edit.
defmodule Lexical.Protocol.Types.SemanticTokens.Registration.Options do
  alias Lexical.Protocol.Proto
  alias Lexical.Protocol.Types
  alias __MODULE__, as: Parent

  defmodule Full1 do
    use Proto
    deftype delta: optional(boolean())
  end

  defmodule Range1 do
    use Proto
    deftype []
  end

  use Proto

  deftype document_selector: one_of([Types.Document.Selector, nil]),
          full: optional(one_of([boolean(), Parent.Full1])),
          id: optional(string()),
          legend: Types.SemanticTokens.Legend,
          range: optional(one_of([boolean(), Parent.Range1])),
          work_done_progress: optional(boolean())
end
