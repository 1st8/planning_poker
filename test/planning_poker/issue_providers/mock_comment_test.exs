defmodule PlanningPoker.IssueProviders.MockCommentTest do
  use ExUnit.Case, async: true

  alias PlanningPoker.IssueProviders.Mock

  setup do
    # Ensure the Mock GenServer is started
    pid = Process.whereis(Mock)

    unless pid do
      {:ok, pid} = Mock.start_link([])
      on_exit(fn -> Process.exit(pid, :normal) end)
    end

    :ok
  end

  describe "post_comment/4" do
    test "posts comment to existing issue" do
      client = Mock.client(user_id: "alice")

      comment_text = "This is a test comment"
      {:ok, comment} = Mock.post_comment(client, "mock-project", "1", comment_text)

      assert comment["id"]
      assert String.starts_with?(comment["id"], "mock-comment-")
      assert comment["body"] == comment_text
      assert comment["author"]["name"] == "Alice Anderson"
      assert comment["author"]["username"] == "alice"
      assert comment["created_at"]
      assert comment["system"] == false
      assert comment["noteable_type"] == "Issue"
      assert comment["noteable_iid"] == "1"
    end

    test "posts comment with different users" do
      bob_client = Mock.client(user_id: "bob")
      carol_client = Mock.client(user_id: "carol")

      {:ok, bob_comment} = Mock.post_comment(bob_client, "mock-project", "2", "Bob's comment")
      {:ok, carol_comment} = Mock.post_comment(carol_client, "mock-project", "3", "Carol's comment")

      assert bob_comment["author"]["name"] == "Bob Builder"
      assert bob_comment["author"]["username"] == "bob"

      assert carol_comment["author"]["name"] == "Carol Chen"
      assert carol_comment["author"]["username"] == "carol"
    end

    test "posts multi-line comment with markdown" do
      client = Mock.client(user_id: "alice")

      comment_text = """
      ## Voice Comment

      This is a **bold** statement.

      - Point 1
      - Point 2
      """

      {:ok, comment} = Mock.post_comment(client, "mock-project", "1", comment_text)

      assert comment["body"] == comment_text
      assert String.contains?(comment["body"], "##")
      assert String.contains?(comment["body"], "**bold**")
    end

    test "returns error for non-existent issue" do
      client = Mock.client(user_id: "alice")

      result = Mock.post_comment(client, "mock-project", "999", "Test comment")

      assert result == {:error, :not_found}
    end

    test "generates unique comment IDs" do
      client = Mock.client(user_id: "alice")

      {:ok, comment1} = Mock.post_comment(client, "mock-project", "1", "Comment 1")
      {:ok, comment2} = Mock.post_comment(client, "mock-project", "1", "Comment 2")

      assert comment1["id"] != comment2["id"]
    end

    test "includes ISO 8601 timestamp" do
      client = Mock.client(user_id: "alice")

      {:ok, comment} = Mock.post_comment(client, "mock-project", "1", "Test")

      # Verify timestamp is valid ISO 8601 format
      assert {:ok, _datetime, _offset} = DateTime.from_iso8601(comment["created_at"])
    end

    test "posts voice transcription format" do
      client = Mock.client(user_id: "alice")

      transcription = """
      ## 🎙️ Voice Comment (Transcribed)

      **Recorded by:** Alice Anderson
      **Transcribed at:** 2024-01-20T10:30:00Z

      ---

      This is the transcribed voice comment text.

      ---

      _This comment was automatically transcribed from a voice recording using Whisper AI._
      """

      {:ok, comment} = Mock.post_comment(client, "mock-project", "1", transcription)

      assert comment["body"] == transcription
      assert String.contains?(comment["body"], "🎙️")
      assert String.contains?(comment["body"], "Whisper AI")
    end
  end
end
