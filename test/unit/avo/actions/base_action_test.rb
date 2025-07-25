require "test_helper"

class BaseActionTest < ActiveSupport::TestCase
  class DestroyerAction < Avo::Actions::ApplicationAction
    class ActionHandler < Avo::Actions::ActionHandler
      def handle_record(model)
        model.destroy!
      end
    end
  end

  class EmptyAction < Avo::Actions::ApplicationAction
    class ActionHandler < Avo::Actions::ActionHandler
      def handle_record(model)
      end
    end
  end

  class WebHookCreateAction < Avo::Actions::ApplicationAction
    class ActionHandler < Avo::Actions::ActionHandler
      def handle_record(user)
        user.web_hooks.create(url: "https://example.com/path")
      end
    end
  end

  make_my_diffs_pretty!

  setup do
    @view_context = mock
    @avo = mock
    @view_context.stubs(:avo).returns(@avo)
    @avo.stubs(:resources_audit_path).returns("resources_audit_path")
    Avo::Current.stubs(:view_context).returns(@view_context)
  end

  test "handles errors" do
    raises_on_each = Class.new do
      def each
        raise "Cannot enumerate"
      end
    end.new
    action = EmptyAction.new

    args = {
      fields: {
        comment: "Sufficiently detailed"
      },
      current_user: create(:admin_github_user, :is_admin),
      resource: nil,
      records: raises_on_each,
      query: nil
    }

    action.handle(**args)

    assert_equal [{ type: :error, body: "Cannot enumerate", timeout: nil }], action.response[:messages]
    assert_equal :keep_modal_open, action.response[:type]
  end

  test "tracks deletions" do
    action = DestroyerAction.new
    webhook = create(:global_web_hook)
    admin = create(:admin_github_user, :is_admin)

    args = {
      fields: {
        comment: "Sufficiently detailed"
      },
      current_user: admin,
      resource: nil,
      records: [webhook],
      query: nil
    }

    action.handle(**args)

    assert_empty action.response[:messages]

    assert_predicate webhook, :destroyed?

    audit = Audit.sole
    as_json = audit.as_json.except("created_at", "updated_at")
    as_json.dig("audited_changes", "records").values.sole["changes"].except!("created_at", "updated_at")

    assert_equal_hash(
      { "id" => audit.id,
        "auditable_type" => "WebHook",
        "auditable_id" => webhook.id,
        "admin_github_user_id" => admin.id,
        "audited_changes" => {
          "records" => {
            webhook.to_global_id.uri.to_s => {
              "changes" => { "id" => [webhook.id, nil], "failure_count" => [0, nil], "user_id" => [webhook.user.id, nil], "url" => [webhook.url, nil],
                            "successes_since_last_failure" => [0, nil], "failures_since_last_success" => [0, nil] },
              "unchanged" => { "rubygem_id" => nil, "disabled_reason" => nil, "disabled_at" => nil, "last_success" => nil, "last_failure" => nil }
            }
          },
          "fields" => {},
          "arguments" => {},
          "models" => [webhook.to_global_id.uri.to_s]
        },
        "comment" => "Sufficiently detailed",
        "action" => "Destroyer action" },
      as_json
    )
  end

  test "tracks no changes" do
    action = EmptyAction.new
    user = create(:user)
    admin = create(:admin_github_user, :is_admin)

    args = {
      fields: {
        comment: "Sufficiently detailed"
      },
      current_user: admin,
      resource: nil,
      records: [user],
      query: nil
    }

    action.handle(**args)

    assert_empty action.response[:messages]

    audit = Audit.sole
    as_json = audit.as_json.except("created_at", "updated_at")

    assert_equal_hash(
      { "id" => audit.id,
        "auditable_type" => "User",
        "auditable_id" => user.id,
        "admin_github_user_id" => admin.id,
        "audited_changes" => {
          "records" => {},
          "fields" => {},
          "arguments" => {},
          "models" => [user.to_global_id.uri.to_s]
        },
        "comment" => "Sufficiently detailed",
        "action" => "Empty action" },
      as_json
    )
  end

  test "tracks insertions" do
    action = WebHookCreateAction.new
    user = create(:user)
    admin = create(:admin_github_user, :is_admin)

    args = {
      fields: {
        comment: "Sufficiently detailed"
      },
      current_user: admin,
      resource: nil,
      records: [user],
      query: nil
    }

    action.handle(**args)

    assert_empty action.response[:messages]

    audit = Audit.sole
    webhook = WebHook.sole
    as_json = audit.as_json.except("created_at", "updated_at")
    as_json.dig("audited_changes", "records").values.sole["changes"].except!("created_at", "updated_at")

    assert_equal_hash(
      { "id" => audit.id,
        "auditable_type" => "User",
        "auditable_id" => user.id,
        "admin_github_user_id" => admin.id,
        "audited_changes" => {
          "records" => {
            webhook.to_global_id.uri.to_s => {
              "changes" => {
                "id" => [nil, webhook.id],
                "user_id" => [nil, user.id],
                "url" => [nil, webhook.url],
                "failure_count" => [nil, 0],
                "rubygem_id" => [nil, nil],
                "disabled_reason" => [nil, nil],
                "disabled_at" => [nil, nil],
                "last_success" => [nil, nil],
                "last_failure" => [nil, nil],
                "successes_since_last_failure" => [nil, 0],
                "failures_since_last_success" => [nil, 0]
              },
            "unchanged" => {}
            }
          },
          "fields" => {},
          "arguments" => {},
          "models" => [user.to_global_id.uri.to_s]
        },
        "comment" => "Sufficiently detailed",
        "action" => "Web hook create action" },
      as_json
    )
  end
end
