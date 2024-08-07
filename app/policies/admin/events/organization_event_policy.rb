class Admin::Events::OrganizationEventPolicy < Admin::ApplicationPolicy
  class Scope < Admin::ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end

  has_association :organization
  has_association :ip_address

  def avo_index? = rubygems_org_admin?
  def avo_show? = rubygems_org_admin?
end
