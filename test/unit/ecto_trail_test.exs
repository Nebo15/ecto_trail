defmodule EctoTrailTest do
  use EctoTrail.DataCase
  alias EctoTrail.Changelog
  alias Ecto.Changeset
  doctest EctoTrail

  describe "insert_and_log/3" do
    test "logs changes when schema is inserted" do
      result = TestRepo.insert_and_log(%ResourcesSchema{name: "name"}, "cowboy")
      assert {:ok, %ResourcesSchema{name: "name"}} = result

      resource = TestRepo.one(ResourcesSchema)
      resource_id = to_string(resource.id)

      assert %{
        changeset: %{},
        actor_id: "cowboy",
        resource_id: ^resource_id,
        resource: "resources"
      } = TestRepo.one(Changelog)
    end

    test "logs changes when changeset is inserted" do
      result =
        %ResourcesSchema{}
        |> Changeset.change(%{name: "My name"})
        |> TestRepo.insert_and_log("cowboy")

      assert {:ok, %ResourcesSchema{name: "My name"}} = result

      resource = TestRepo.one(ResourcesSchema)
      resource_id = to_string(resource.id)

      assert %{
        changeset: %{"name" => "My name"},
        actor_id: "cowboy",
        resource_id: ^resource_id,
        resource: "resources"
      } = TestRepo.one(Changelog)
    end

    test "logs changes when changeset is empty" do
      result =
        %ResourcesSchema{}
        |> Changeset.change(%{})
        |> TestRepo.insert_and_log("cowboy")

      assert {:ok, %ResourcesSchema{name: nil}} = result

      resource = TestRepo.one(ResourcesSchema)
      resource_id = to_string(resource.id)

      assert %{
        changeset: changes,
        actor_id: "cowboy",
        resource_id: ^resource_id,
        resource: "resources"
      } = TestRepo.one(Changelog)

      assert %{} == changes
    end

    test "logs changes when changeset with embed is inserted" do
      attrs = %{
        name: "My name",
        array: ["apple", "banana"],
        map: %{longitude: 50.45000, latitude: 30.52333},
        location: %Geo.Point{coordinates: {49.44, 17.87}},
        data: %{key2: "key2"},
        category: %{"title" => "test"},
        comments: [
          %{"title" => "wow"},
          %{"title" => "very impressive"},
        ],
        items: [
          %{name: "Morgan"},
          %{name: "Freeman"}
        ]}

      result =
        %ResourcesSchema{}
        |> Changeset.cast(attrs, [:name, :array, :map, :location])
        |> Changeset.cast_embed(:data, with: &ResourcesSchema.embed_changeset/2)
        |> Changeset.cast_embed(:items, with: &ResourcesSchema.embeds_many_changeset/2)
        |> Changeset.cast_assoc(:category)
        |> Changeset.cast_assoc(:comments)
        |> TestRepo.insert_and_log("cowboy")

      assert {:ok, %ResourcesSchema{name: "My name"}} = result

      resource = TestRepo.one(ResourcesSchema)
      resource_id = to_string(resource.id)

      assert %{
        changeset: changes,
        actor_id: "cowboy",
        resource_id: ^resource_id,
        resource: "resources"
      } = TestRepo.one(Changelog)

      assert %{
        "name" => "My name",
        "data" => %{"key2" => "key2"},
        "category" => %{"title" => "test"},
        "comments" => [
          %{"title" => "wow"},
          %{"title" => "very impressive"},
        ],
        "items" => [
          %{"name" => "Morgan"},
          %{"name" => "Freeman"}
        ],
        "location" => "%Geo.Point{coordinates: {49.44, 17.87}, srid: nil}",
        "array" => ["apple", "banana"],
        "map" => %{
          "latitude" => 30.52333,
          "longitude" => 50.45}
        } == changes
    end

    test "returns error when changeset is invalid" do
      changeset =
        %ResourcesSchema{}
        |> Changeset.change(%{name: "My name"})
        |> Changeset.add_error(:name, "invalid")

      result = TestRepo.insert_and_log(changeset, "cowboy")
      assert {:error, %Changeset{valid?: false}} = result

      assert [] == TestRepo.all(ResourcesSchema)
      assert [] == TestRepo.all(Changelog)
    end
  end

  describe "update_and_log/3" do
    setup do
      {:ok, schema} = TestRepo.insert(%ResourcesSchema{name: "name"})
      {:ok, %{schema: schema}}
    end

    test "logs changes when changeset is updated", %{schema: schema} do
      result =
        schema
        |> Changeset.change(%{name: "My new name"})
        |> TestRepo.update_and_log("cowboy")

      assert {:ok, %ResourcesSchema{name: "My new name"}} = result

      resource = TestRepo.one(ResourcesSchema)
      resource_id = to_string(resource.id)

      assert %{
        changeset: %{"name" => "My new name"},
        actor_id: "cowboy",
        resource_id: ^resource_id,
        resource: "resources"
      } = TestRepo.one(Changelog)
    end

    test "returns error when changeset is invalid", %{schema: schema} do
      changeset =
        schema
        |> Changeset.change(%{name: "My new name"})
        |> Changeset.add_error(:name, "invalid")

      result = TestRepo.update_and_log(changeset, "cowboy")
      assert {:error, %Changeset{valid?: false}} = result

      assert [%{name: "name"}] = TestRepo.all(ResourcesSchema)
      assert [] == TestRepo.all(Changelog)
    end

    test "log changes when mulpiple changesets are updated" do
      insert_multiple_records()
      names = TestRepo.all(from es in ResourcesSchema, where: es.name == "multi_name")
      assert 3 == Enum.count(names)

      changes = Enum.map(names, fn(name) -> Ecto.Changeset.change(name, %{name: "updated_name"}) end)
      assert {3, nil} = TestRepo.update_all_and_log(changes, "cowboy")

      changelog = TestRepo.all(from cl in Changelog, select: cl.changeset)
      assert 3 == Enum.count(changelog)
      assert Enum.all?(changelog, fn(%{"name" => updated}) -> updated == "updated_name" end)
    end

    test "returns error when some changeset from changesets is invalid" do
      insert_multiple_records()
      names = TestRepo.all(from es in ResourcesSchema, where: es.name == "multi_name")
      assert 3 == Enum.count(names)

      [ch1, ch2, ch3] = Enum.map(names, fn(name) -> Ecto.Changeset.change(name, %{name: "updated_name"}) end)
      inv_ch = Changeset.add_error(ch2, :name, "invalid")
      assert {:error, %Ecto.Changeset{}} = TestRepo.update_all_and_log([ch1, inv_ch, ch3], "cowboy")

      orig_names = TestRepo.all(from es in ResourcesSchema, where: es.name == "multi_name", select: es.name)
      assert 3 == Enum.count(orig_names)
      assert Enum.all?(orig_names, &(&1 == "multi_name"))
      assert [] == TestRepo.all(Changelog)
    end

    defp insert_multiple_records do
      {:ok, _} = TestRepo.insert(%ResourcesSchema{name: "multi_name"})
      {:ok, _} = TestRepo.insert(%ResourcesSchema{name: "multi_name"})
      {:ok, _} = TestRepo.insert(%ResourcesSchema{name: "multi_name"})
    end
  end
end
