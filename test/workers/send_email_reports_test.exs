defmodule Plausible.Workers.EmailReportsTest do
  use Plausible.DataCase
  use Bamboo.Test
  alias Plausible.Workers.SendEmailReports

  defp perform(args) do
    SendEmailReports.new(args) |> Oban.insert!()
    Oban.drain_queue(:email_reports)
  end

  describe "weekly reports" do
    test "sends weekly report on Monday 9am local timezone" do
      site = insert(:site, timezone: "US/Eastern")
      insert(:weekly_report, site: site, recipients: ["user@email.com"])
      # 2pm UTC is 10am EST
      time = Timex.now() |> Timex.beginning_of_week() |> Timex.shift(hours: 14)

      perform(%{"current_time" => time})

      assert_email_delivered_with(
        subject: "Weekly report for #{site.domain}",
        to: [nil: "user@email.com"]
      )
    end

    test "does not send a report on Monday before 9am in local timezone" do
      site = insert(:site, timezone: "US/Eastern")
      insert(:weekly_report, site: site, recipients: ["user@email.com"])
      # 12pm UTC is 8am EST
      time = Timex.now() |> Timex.beginning_of_week() |> Timex.shift(hours: 12)

      perform(%{"current_time" => time})

      assert_no_emails_delivered()
    end

    test "does not send a report on Tuesday" do
      site = insert(:site)
      insert(:weekly_report, site: site, recipients: ["user@email.com"])
      time = Timex.now() |> Timex.beginning_of_week() |> Timex.shift(days: 1, hours: 10)

      perform(%{"current_time" => time})

      assert_no_emails_delivered()
    end

    test "does not send the same report multiple times on the same week" do
      site = insert(:site)
      insert(:weekly_report, site: site, recipients: ["user@email.com"])
      time = Timex.now() |> Timex.beginning_of_week() |> Timex.shift(hours: 10)

      perform(%{"current_time" => time})

      assert_email_delivered_with(
        subject: "Weekly report for #{site.domain}",
        to: [nil: "user@email.com"]
      )

      perform(%{"current_time" => time})
      assert_no_emails_delivered()
    end
  end

  describe "monthly_reports" do
    test "sends monthly report on the 1st of the month after 9am local timezone" do
      site = insert(:site, timezone: "US/Eastern")
      insert(:monthly_report, site: site, recipients: ["user@email.com"])
      {:ok, time, _} = DateTime.from_iso8601("2019-04-01T14:00:00Z")

      perform(%{"current_time" => time})

      assert_email_delivered_with(
        subject: "March report for #{site.domain}",
        to: [nil: "user@email.com"]
      )
    end

    test "does not send a report on the 1st of the month before 9am in local timezone" do
      site = insert(:site, timezone: "US/Eastern")
      insert(:monthly_report, site: site, recipients: ["user@email.com"])
      # 12pm UTC is 8am EST
      time = Timex.now() |> Timex.beginning_of_month() |> Timex.shift(hours: 12)

      perform(%{"current_time" => time})

      assert_no_emails_delivered()
    end

    test "does not send a report on the 2nd of the month" do
      site = insert(:site)
      insert(:monthly_report, site: site, recipients: ["user@email.com"])
      time = Timex.now() |> Timex.beginning_of_month() |> Timex.shift(days: 1, hours: 10)

      perform(%{"current_time" => time})

      assert_no_emails_delivered()
    end

    test "does not send the same report multiple times on the same month" do
      site = insert(:site)
      insert(:monthly_report, site: site, recipients: ["user@email.com"])
      {:ok, time, _} = DateTime.from_iso8601("2019-02-01T11:00:00Z")

      perform(%{"current_time" => time})

      assert_email_delivered_with(
        subject: "January report for #{site.domain}",
        to: [nil: "user@email.com"]
      )

      perform(%{"current_time" => time})
      assert_no_emails_delivered()
    end
  end
end
