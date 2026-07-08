defmodule Unicode.Set.ParseError do
  @moduledoc """
  Exception raised when a Unicode Set cannot be parsed.

  """
  defexception [:message]

  def exception(message) do
    %__MODULE__{message: message}
  end
end
