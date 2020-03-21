class Admin::BudgetGroupsController < Admin::BaseController
  include Translatable
  include FeatureFlags
  feature_flag :budgets

  before_action :load_budget
  before_action :load_groups, only: [:index, :create]
  before_action :load_group, except: [:new, :index, :create]

  def index
    @group = @budget.groups.new
  end

  def new
    @group = @budget.groups.new
  end

  def edit
  end

  def create
    @group = @budget.groups.new(budget_group_params)
    if @group.save
      redirect_to groups_index, notice: t("admin.budget_groups.create.notice")
    else
      render :index
    end
  end

  def update
    if @group.update(budget_group_params)
      redirect_to groups_index, notice: t("admin.budget_groups.update.notice")
    else
      render :edit
    end
  end

  def destroy
    if @group.headings.any?
      redirect_to groups_index, alert: t("admin.budget_groups.destroy.unable_notice")
    else
      @group.destroy!
      redirect_to groups_index, notice: t("admin.budget_groups.destroy.success_notice")
    end
  end

  private

    def load_budget
      @budget = Budget.find_by_slug_or_id! params[:budget_id]
    end

    def load_groups
      @groups = @budget.groups.order(:id)
    end

    def load_group
      @group = @budget.groups.find_by_slug_or_id! params[:id]
    end

    def groups_index
      admin_budget_groups_path(@budget)
    end

    def budget_group_params
      valid_attributes = [:max_votable_headings]
      params.require(:budget_group).permit(*valid_attributes, translation_params(Budget::Group))
    end
end
