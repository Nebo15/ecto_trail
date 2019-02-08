defmodule EctoTrail.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias TestRepo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import EctoTrail.DataCase
    end
  end

  setup tags do
    :ok = Sandbox.checkout(TestRepo)
    :ok = Sandbox.checkout(TestRepoWithCustomSchema)

    unless tags[:async] do
      Sandbox.mode(TestRepo, {:shared, self()})
      Sandbox.mode(TestRepoWithCustomSchema, {:shared, self()})
    end

    :ok
  end

  @doc """
  Helper for returning list of errors in a struct when given certain data.
  ## Examples
  Given a User schema that lists `:name` as a required field and validates
  `:password` to be safe, it would return:
      iex> errors_on(%User{}, %{password: "password"})
      [password: "is unsafe", name: "is blank"]
  You could then write your assertion like:
      assert {:password, "is unsafe"} in errors_on(%User{}, %{password: "password"})
  """
  def errors_on(struct, data) do
    data
    |> (&struct.__struct__.changeset(struct, &1)).()
    |> Enum.flat_map(fn {key, errors} -> for msg <- errors, do: {key, msg} end)
  end
end
