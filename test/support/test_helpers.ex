defmodule RemoteRetro.TestHelpers do
  use Wallaby.DSL
  alias RemoteRetro.{Repo, User, Vote, Idea, Participation}

  def use_all_votes(%{user: user, idea: idea} = context) do
    now = DateTime.utc_now
    vote = [user_id: user.id, idea_id: idea.id, inserted_at: now, updated_at: now]
    Repo.insert_all(Vote, [vote, vote, vote, vote, vote])
    context
  end

  defp user_name_atom(name) do
    String.replace(name, ~r/ +/, "") |> Macro.underscore |> String.to_atom
  end

  defp user_map(users) do
    Enum.reduce users, %{}, fn user, acc ->
      Map.put(acc, user_name_atom(user.name), user)
    end
  end

  defp persist_user(user) do
    User.upsert_record_from(oauth_info: user)
  end

  defp persist_participation_for_users(users, retro) do
    Enum.each(users, fn(user) ->
      %Participation{retro_id: retro.id, user_id: user.id} |> Repo.insert!
    end)
  end

  def persist_additional_users_for_retro(%{additional_users: additional_users, retro: retro} = context) do
    persisted_users = Enum.map(additional_users, fn(user) ->
      {:ok, user} = persist_user(user)
      user
    end)
    persist_participation_for_users(persisted_users, retro)
    Map.merge(context, user_map(persisted_users))
  end

  defp persist_assigned_idea(user, idea, retro) do
    %Idea{assignee_id: user.id, body: idea.body, category: idea.category, retro_id: retro.id, user_id: user.id} |> Repo.insert!
  end

  defp persist_unassigned_idea(user, idea, retro) do
    Map.merge(idea, %{retro_id: retro.id, user_id: user.id}) |> Repo.insert!
  end

  def persist_idea_for_retro(%{idea: idea, retro: retro, user: user} = context) do
    idea = if idea.category == "action-item" do
            persist_assigned_idea(user, idea, retro)
          else
            persist_unassigned_idea(user, idea, retro)
          end
    Map.put(context, :idea, idea)
  end

  def new_browser_session(metadata \\ %{}) do
    :timer.sleep(50)
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    resize_window(session, 1000, 1000)
  end

  def stub_js_confirms_for_phantomjs(session) do
    execute_script(session, "window.confirm = function(){ return true; }")
  end

  def click_and_confirm(facilitator_session, button_text) do
    facilitator_session |> find(Query.button(button_text)) |> Element.click
    facilitator_session |> find(Query.button("Yes")) |> Element.click
  end

  def authenticate(session) do
    visit(session, "/auth/google/callback?code=love")
  end

  def submit_idea(session, %{ category: category, body: body }) do
    session
    |> find(Query.css("form"))
    |> click(Query.option(category))
    |> fill_in(Query.text_field("idea"), with: body)
    |> click(Query.button("Submit"))

    session
  end

  def delete_idea(session, %{body: body}) do
    session
    |> find(Query.css(".ideas li", text: body))
    |> click(Query.css(".remove.icon"))
  end
end
