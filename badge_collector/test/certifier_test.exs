defmodule BadgeCollector.CertifierTest do
  use BadgeCollector.DataCase, async: false

  alias BadgeCollector.{Action, Badge, Certificate, Certifier, User}

  alias BadgeCollector.Certifiers.{
    LoginStreakCertifier,
    PurchaseCountCertifier,
    TotalSpentCertifier
  }

  # ------------------------------------------------------------------
  # fixtures
  # ------------------------------------------------------------------

  defp user_fixture(attrs \\ %{}) do
    email = Map.get(attrs, :email, "user#{System.unique_integer([:positive])}@example.com")

    %User{}
    |> User.changeset(%{email: email, password: "correcthorsebatterystaple"})
    |> Repo.insert!()
  end

  defp badge_fixture(attrs) do
    defaults = %{name: "Badge #{System.unique_integer([:positive])}", hidden: false}

    %Badge{}
    |> Badge.changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp login_fixture(user, days_ago \\ 0) do
    at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-days_ago * 86_400, :second)
      |> NaiveDateTime.truncate(:second)

    Repo.insert!(%Action{
      type: "login",
      data: "",
      user_id: user.id,
      inserted_at: at,
      updated_at: at
    })
  end

  defp purchase_fixture(user, data) do
    Repo.insert!(%Action{type: "buy_item", data: data, user_id: user.id})
  end

  # ------------------------------------------------------------------
  # Action.parse_purchase/1
  # ------------------------------------------------------------------

  describe "Action.parse_purchase/1" do
    test "splits a well formed payload into name and cost" do
      action = %Action{type: "buy_item", data: "blue sticker|4.50"}
      assert {:ok, "blue sticker", 4.50} = Action.parse_purchase(action)
    end

    test "trims surrounding whitespace on both halves" do
      action = %Action{type: "buy_item", data: "  gold star  |  12.00  "}
      assert {:ok, "gold star", 12.00} = Action.parse_purchase(action)
    end

    test "keeps pipes that appear inside the item name out of the cost" do
      action = %Action{type: "buy_item", data: "a|b|3.00"}
      # parts: 2 means everything after the first pipe is the cost, which is
      # not a number here, so the whole payload is rejected
      assert :error = Action.parse_purchase(action)
    end

    test "rejects a missing cost" do
      assert :error = Action.parse_purchase(%Action{type: "buy_item", data: "lonely item"})
    end

    test "rejects a non numeric cost" do
      assert :error = Action.parse_purchase(%Action{type: "buy_item", data: "item|free"})
    end

    test "rejects trailing junk after the number" do
      assert :error = Action.parse_purchase(%Action{type: "buy_item", data: "item|4.50 usd"})
    end

    test "rejects an action of the wrong type" do
      assert :error = Action.parse_purchase(%Action{type: "login", data: ""})
    end

    test "rejects nil data" do
      assert :error = Action.parse_purchase(%Action{type: "buy_item", data: nil})
    end
  end

  # ------------------------------------------------------------------
  # LoginStreakCertifier
  # ------------------------------------------------------------------

  describe "LoginStreakCertifier.handles/0 and relavent_action?/1" do
    test "claims the login_streak unlock type" do
      assert LoginStreakCertifier.handles() == "login_streak"
    end

    test "cares about login actions" do
      assert LoginStreakCertifier.relavent_action?(%Action{type: "login", data: ""})
    end

    test "ignores purchases" do
      refute LoginStreakCertifier.relavent_action?(%Action{type: "buy_item", data: "x|1.0"})
    end

    test "ignores unknown action types" do
      refute LoginStreakCertifier.relavent_action?(%Action{type: "sneeze", data: ""})
    end
  end

  describe "LoginStreakCertifier.try_certify/2" do
    setup do
      %{badge: badge_fixture(%{unlock_type: "login_streak", unlock_args: "3"})}
    end

    test "issues a certificate once the streak is long enough", %{badge: badge} do
      user = user_fixture()
      for days_ago <- 0..2, do: login_fixture(user, days_ago)

      assert %Certificate{} = cert = LoginStreakCertifier.try_certify(badge, user)
      assert cert.user_id == user.id
      assert cert.badge_id == badge.id
      assert cert.info == "3 day login streak"
    end

    test "the certificate it returns is actually persisted", %{badge: badge} do
      user = user_fixture()
      for days_ago <- 0..2, do: login_fixture(user, days_ago)

      cert = LoginStreakCertifier.try_certify(badge, user)
      assert Repo.get(Certificate, cert.id)
    end

    test "issues when the streak overshoots the requirement", %{badge: badge} do
      user = user_fixture()
      for days_ago <- 0..9, do: login_fixture(user, days_ago)

      assert %Certificate{info: "10 day login streak"} =
               LoginStreakCertifier.try_certify(badge, user)
    end

    test "returns nil when the streak is one day short", %{badge: badge} do
      user = user_fixture()
      for days_ago <- 0..1, do: login_fixture(user, days_ago)

      assert is_nil(LoginStreakCertifier.try_certify(badge, user))
    end

    test "returns nil when the user has never logged in", %{badge: badge} do
      assert is_nil(LoginStreakCertifier.try_certify(badge, user_fixture()))
    end

    test "several logins in one day count as one", %{badge: badge} do
      user = user_fixture()
      for _ <- 1..5, do: login_fixture(user, 0)
      login_fixture(user, 1)

      # two distinct days, not six
      assert is_nil(LoginStreakCertifier.try_certify(badge, user))
    end

    test "a gap breaks the streak", %{badge: badge} do
      user = user_fixture()
      for days_ago <- [0, 1, 4, 5, 6], do: login_fixture(user, days_ago)

      # counts back from today and stops at the hole: 2, not 5
      assert is_nil(LoginStreakCertifier.try_certify(badge, user))
    end

    test "another user's logins do not count", %{badge: badge} do
      user = user_fixture()
      stranger = user_fixture()

      login_fixture(user, 0)
      for days_ago <- 1..5, do: login_fixture(stranger, days_ago)

      assert is_nil(LoginStreakCertifier.try_certify(badge, user))
    end

    test "purchases do not count toward a login streak", %{badge: badge} do
      user = user_fixture()
      login_fixture(user, 0)
      for _ <- 1..5, do: purchase_fixture(user, "thing|1.00")

      assert is_nil(LoginStreakCertifier.try_certify(badge, user))
    end

    test "nil unlock_args falls back to a one day requirement" do
      badge = badge_fixture(%{unlock_type: "login_streak", unlock_args: nil})
      user = user_fixture()
      login_fixture(user, 0)

      assert %Certificate{info: "1 day login streak"} =
               LoginStreakCertifier.try_certify(badge, user)
    end

    test "raises when unlock_args is not a number" do
      badge = badge_fixture(%{unlock_type: "login_streak", unlock_args: "seven"})
      user = user_fixture()
      login_fixture(user, 0)

      assert_raise ArgumentError, fn ->
        LoginStreakCertifier.try_certify(badge, user)
      end
    end
  end

  # ------------------------------------------------------------------
  # PurchaseCountCertifier
  # ------------------------------------------------------------------

  describe "PurchaseCountCertifier.handles/0 and relavent_action?/1" do
    test "claims the purchase_count unlock type" do
      assert PurchaseCountCertifier.handles() == "purchase_count"
    end

    test "cares about purchases" do
      assert PurchaseCountCertifier.relavent_action?(%Action{type: "buy_item", data: "x|1.0"})
    end

    test "cares about purchases even when the payload is malformed" do
      # the count does not depend on parsing the cost
      assert PurchaseCountCertifier.relavent_action?(%Action{type: "buy_item", data: "junk"})
    end

    test "ignores logins" do
      refute PurchaseCountCertifier.relavent_action?(%Action{type: "login", data: ""})
    end
  end

  describe "PurchaseCountCertifier.try_certify/2" do
    setup do
      %{badge: badge_fixture(%{unlock_type: "purchase_count", unlock_args: "3"})}
    end

    test "issues once the count is reached", %{badge: badge} do
      user = user_fixture()
      for n <- 1..3, do: purchase_fixture(user, "item #{n}|1.00")

      assert %Certificate{info: "3 purchases"} = PurchaseCountCertifier.try_certify(badge, user)
    end

    test "returns nil below the threshold", %{badge: badge} do
      user = user_fixture()
      for n <- 1..2, do: purchase_fixture(user, "item #{n}|1.00")

      assert is_nil(PurchaseCountCertifier.try_certify(badge, user))
    end

    test "returns nil for a user with no actions at all", %{badge: badge} do
      assert is_nil(PurchaseCountCertifier.try_certify(badge, user_fixture()))
    end

    test "counts malformed purchases too", %{badge: badge} do
      user = user_fixture()
      purchase_fixture(user, "good|1.00")
      purchase_fixture(user, "no cost here")
      purchase_fixture(user, "also bad")

      assert %Certificate{info: "3 purchases"} = PurchaseCountCertifier.try_certify(badge, user)
    end

    test "logins are not purchases", %{badge: badge} do
      user = user_fixture()
      purchase_fixture(user, "item|1.00")
      for days_ago <- 0..9, do: login_fixture(user, days_ago)

      assert is_nil(PurchaseCountCertifier.try_certify(badge, user))
    end

    test "another user's purchases do not count", %{badge: badge} do
      user = user_fixture()
      stranger = user_fixture()

      purchase_fixture(user, "mine|1.00")
      for n <- 1..10, do: purchase_fixture(stranger, "theirs #{n}|1.00")

      assert is_nil(PurchaseCountCertifier.try_certify(badge, user))
    end

    test "nil unlock_args falls back to a single purchase" do
      badge = badge_fixture(%{unlock_type: "purchase_count", unlock_args: nil})
      user = user_fixture()
      purchase_fixture(user, "first|0.99")

      assert %Certificate{info: "1 purchases"} = PurchaseCountCertifier.try_certify(badge, user)
    end
  end

  # ------------------------------------------------------------------
  # TotalSpentCertifier
  # ------------------------------------------------------------------

  describe "TotalSpentCertifier.handles/0 and relavent_action?/1" do
    test "claims the total_spent unlock type" do
      assert TotalSpentCertifier.handles() == "total_spent"
    end

    test "cares about a parseable purchase" do
      assert TotalSpentCertifier.relavent_action?(%Action{type: "buy_item", data: "x|1.00"})
    end

    test "ignores a purchase whose cost cannot be read" do
      refute TotalSpentCertifier.relavent_action?(%Action{type: "buy_item", data: "x|free"})
    end

    test "ignores logins" do
      refute TotalSpentCertifier.relavent_action?(%Action{type: "login", data: ""})
    end
  end

  describe "TotalSpentCertifier.try_certify/2" do
    setup do
      %{badge: badge_fixture(%{unlock_type: "total_spent", unlock_args: "20.0"})}
    end

    test "issues once spending reaches the threshold", %{badge: badge} do
      user = user_fixture()
      purchase_fixture(user, "sticker|10.50")
      purchase_fixture(user, "pin|9.50")

      assert %Certificate{info: "spent 20.00"} = TotalSpentCertifier.try_certify(badge, user)
    end

    test "issues when spending overshoots", %{badge: badge} do
      user = user_fixture()
      purchase_fixture(user, "poster|99.99")

      assert %Certificate{info: "spent 99.99"} = TotalSpentCertifier.try_certify(badge, user)
    end

    test "returns nil below the threshold", %{badge: badge} do
      user = user_fixture()
      purchase_fixture(user, "sticker|19.99")

      assert is_nil(TotalSpentCertifier.try_certify(badge, user))
    end

    test "skips unparseable payloads instead of failing the tally", %{badge: badge} do
      user = user_fixture()
      purchase_fixture(user, "good|15.00")
      purchase_fixture(user, "garbage row")
      purchase_fixture(user, "another|5.00")

      assert %Certificate{info: "spent 20.00"} = TotalSpentCertifier.try_certify(badge, user)
    end

    test "returns nil when every payload is unparseable", %{badge: badge} do
      user = user_fixture()
      for _ <- 1..5, do: purchase_fixture(user, "nonsense")

      assert is_nil(TotalSpentCertifier.try_certify(badge, user))
    end

    test "another user's spending does not count", %{badge: badge} do
      user = user_fixture()
      stranger = user_fixture()

      purchase_fixture(user, "mine|1.00")
      purchase_fixture(stranger, "theirs|500.00")

      assert is_nil(TotalSpentCertifier.try_certify(badge, user))
    end

    test "raises when unlock_args is written as an integer" do
      # String.to_float/1 will not accept "100" - seed these badges as "100.0"
      badge = badge_fixture(%{unlock_type: "total_spent", unlock_args: "100"})
      user = user_fixture()
      purchase_fixture(user, "item|1.00")

      assert_raise ArgumentError, fn ->
        TotalSpentCertifier.try_certify(badge, user)
      end
    end
  end

  # ------------------------------------------------------------------
  # Certifier.run/2
  # ------------------------------------------------------------------

  describe "Certifier.run/2" do
    test "routes a login action to the streak certifier" do
      user = user_fixture()
      badge = badge_fixture(%{unlock_type: "login_streak", unlock_args: "2"})
      login_fixture(user, 1)
      action = login_fixture(user, 0)

      assert [%Certificate{badge_id: badge_id}] = Certifier.run(action, user)
      assert badge_id == badge.id
    end

    test "routes a purchase to every certifier that wants it" do
      user = user_fixture()
      count_badge = badge_fixture(%{unlock_type: "purchase_count", unlock_args: "2"})
      spent_badge = badge_fixture(%{unlock_type: "total_spent", unlock_args: "10.0"})

      purchase_fixture(user, "first|6.00")
      action = purchase_fixture(user, "second|6.00")

      issued = Certifier.run(action, user)
      badge_ids = issued |> Enum.map(& &1.badge_id) |> Enum.sort()

      assert length(issued) == 2
      assert badge_ids == Enum.sort([count_badge.id, spent_badge.id])
    end

    test "issues several badges of the same type at once" do
      user = user_fixture()
      bronze = badge_fixture(%{unlock_type: "purchase_count", unlock_args: "1"})
      silver = badge_fixture(%{unlock_type: "purchase_count", unlock_args: "3"})
      gold = badge_fixture(%{unlock_type: "purchase_count", unlock_args: "50"})

      for n <- 1..2, do: purchase_fixture(user, "item #{n}|1.00")
      action = purchase_fixture(user, "item 3|1.00")

      badge_ids = action |> Certifier.run(user) |> Enum.map(& &1.badge_id) |> Enum.sort()

      assert badge_ids == Enum.sort([bronze.id, silver.id])
      refute gold.id in badge_ids
    end

    test "returns an empty list when nothing is earned" do
      user = user_fixture()
      badge_fixture(%{unlock_type: "login_streak", unlock_args: "30"})
      action = login_fixture(user, 0)

      assert [] = Certifier.run(action, user)
    end

    test "an empty list is the ordinary outcome, not an error" do
      user = user_fixture()
      action = login_fixture(user, 0)

      # no badges exist at all
      assert [] = Certifier.run(action, user)
    end

    test "a purchase does not trip a login streak badge" do
      user = user_fixture()
      badge_fixture(%{unlock_type: "login_streak", unlock_args: "1"})
      for days_ago <- 0..5, do: login_fixture(user, days_ago)

      action = purchase_fixture(user, "item|1.00")

      # the streak is long enough, but this action is not a login
      assert [] = Certifier.run(action, user)
    end

    test "considers hidden badges" do
      user = user_fixture()
      hidden = badge_fixture(%{unlock_type: "purchase_count", unlock_args: "1", hidden: true})
      action = purchase_fixture(user, "item|1.00")

      assert [%Certificate{badge_id: badge_id}] = Certifier.run(action, user)
      assert badge_id == hidden.id
    end

    test "ignores badges whose unlock type has no certifier" do
      user = user_fixture()
      badge_fixture(%{unlock_type: "disabled", unlock_args: nil})
      earnable = badge_fixture(%{unlock_type: "purchase_count", unlock_args: "1"})

      action = purchase_fixture(user, "item|1.00")

      assert [%Certificate{badge_id: badge_id}] = Certifier.run(action, user)
      assert badge_id == earnable.id
    end

    test "survives a badge with no matching certifier and no earnable badges" do
      user = user_fixture()
      badge_fixture(%{unlock_type: "phase of the moon", unlock_args: "waxing"})
      action = login_fixture(user, 0)

      assert [] = Certifier.run(action, user)
    end

    test "does not award the same badge twice" do
      user = user_fixture()
      badge_fixture(%{unlock_type: "purchase_count", unlock_args: "1"})

      first = purchase_fixture(user, "first|1.00")
      assert [%Certificate{}] = Certifier.run(first, user)

      second = purchase_fixture(user, "second|1.00")
      assert [] = Certifier.run(second, user)
    end

    test "one user earning a badge does not affect another" do
      user = user_fixture()
      stranger = user_fixture()
      badge_fixture(%{unlock_type: "purchase_count", unlock_args: "1"})

      mine = purchase_fixture(user, "mine|1.00")
      assert [%Certificate{}] = Certifier.run(mine, user)

      theirs = purchase_fixture(stranger, "theirs|1.00")
      assert [%Certificate{user_id: user_id}] = Certifier.run(theirs, stranger)
      assert user_id == stranger.id
    end

    test "every returned certificate is persisted" do
      user = user_fixture()
      badge_fixture(%{unlock_type: "purchase_count", unlock_args: "1"})
      badge_fixture(%{unlock_type: "total_spent", unlock_args: "1.0"})

      action = purchase_fixture(user, "item|5.00")
      issued = Certifier.run(action, user)

      assert length(issued) == 2
      for cert <- issued, do: assert(Repo.get(Certificate, cert.id))
    end

    test "a badge with bad unlock_args surfaces the error rather than swallowing it" do
      user = user_fixture()
      badge_fixture(%{unlock_type: "total_spent", unlock_args: "not a number"})
      action = purchase_fixture(user, "item|5.00")

      assert catch_error(Certifier.run(action, user))
    end
  end

  # ------------------------------------------------------------------
  # Certifier.issue/3
  # ------------------------------------------------------------------

  describe "Certifier.issue/3" do
    test "returns the inserted certificate" do
      user = user_fixture()
      badge = badge_fixture(%{unlock_type: "login_streak", unlock_args: "1"})

      assert %Certificate{} = cert = Certifier.issue(user.id, badge.id, "hello")
      assert cert.info == "hello"
      assert Repo.get(Certificate, cert.id)
    end

    test "returns nil instead of raising on a duplicate" do
      user = user_fixture()
      badge = badge_fixture(%{unlock_type: "login_streak", unlock_args: "1"})

      assert %Certificate{} = Certifier.issue(user.id, badge.id, "first")
      assert is_nil(Certifier.issue(user.id, badge.id, "second"))
      assert Repo.aggregate(Certificate, :count) == 1
    end

    test "returns nil when the badge does not exist" do
      user = user_fixture()
      assert is_nil(Certifier.issue(user.id, 999_999, "ghost badge"))
    end

    test "returns nil when the user does not exist" do
      badge = badge_fixture(%{unlock_type: "login_streak", unlock_args: "1"})
      assert is_nil(Certifier.issue(999_999, badge.id, "ghost user"))
    end
  end

  # ------------------------------------------------------------------
  # Certificate.new/3
  # ------------------------------------------------------------------

  describe "Certificate.new/3" do
    test "defaults info to an empty string" do
      user = user_fixture()
      badge = badge_fixture(%{unlock_type: "login_streak", unlock_args: "1"})

      assert {:ok, %Certificate{info: ""}} = Certificate.new(user.id, badge.id)
    end

    test "reports the unique violation as an error tuple" do
      user = user_fixture()
      badge = badge_fixture(%{unlock_type: "login_streak", unlock_args: "1"})

      assert {:ok, _} = Certificate.new(user.id, badge.id, "first")
      assert {:error, errors} = Certificate.new(user.id, badge.id, "again")
      assert is_list(errors)
    end
  end

  # ------------------------------------------------------------------
  # User.unearned_badges/2, which drives the whole loop
  # ------------------------------------------------------------------

  describe "User.unearned_badges/2" do
    setup do
      user = user_fixture()

      visible = badge_fixture(%{unlock_type: "purchase_count", unlock_args: "1"})
      hidden = badge_fixture(%{unlock_type: "purchase_count", unlock_args: "2", hidden: true})

      %{user: user, visible: visible, hidden: hidden}
    end

    test "hides hidden badges by default", ctx do
      ids = ctx.user |> User.unearned_badges() |> Enum.map(& &1.id)

      assert ctx.visible.id in ids
      refute ctx.hidden.id in ids
    end

    test "includes hidden badges when asked", ctx do
      ids = ctx.user |> User.unearned_badges(true) |> Enum.map(& &1.id)

      assert ctx.visible.id in ids
      assert ctx.hidden.id in ids
    end

    test "drops badges the user already holds", ctx do
      Certifier.issue(ctx.user.id, ctx.visible.id, "earned")

      ids = ctx.user |> User.unearned_badges(true) |> Enum.map(& &1.id)

      refute ctx.visible.id in ids
      assert ctx.hidden.id in ids
    end

    test "another user's certificates do not hide badges from this user", ctx do
      stranger = user_fixture()
      Certifier.issue(stranger.id, ctx.visible.id, "theirs")

      ids = ctx.user |> User.unearned_badges(true) |> Enum.map(& &1.id)
      assert ctx.visible.id in ids
    end

    test "earned_badges/1 is the mirror image", ctx do
      Certifier.issue(ctx.user.id, ctx.visible.id, "earned at last")

      assert [badge] = User.earned_badges(ctx.user)
      assert badge.id == ctx.visible.id
      assert badge.cert_info == "earned at last"
      assert badge.certified_at
    end
  end
end
