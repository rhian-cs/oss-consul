class Admin::BudgetsController < Admin::BaseController
  include Translatable
  include ReportAttributes
  include ImageAttributes
  include FeatureFlags
  feature_flag :budgets

  has_filters %w[all open finished], only: :index

  before_action :load_budget, except: [:index, :new, :create]
  before_action :load_staff, only: [:new, :create, :edit, :update, :show]
  before_action :set_budget_mode, only: [:new, :create, :switch_group]
  load_and_authorize_resource

  def index
    @budgets = Budget.send(@current_filter).order(created_at: :desc).page(params[:page])
  end

  def show
    render :edit
  end

  def new
    @mode ||= "multiple"
  end

  def edit
  end

  def publish
    @budget.publish!
    redirect_to edit_admin_budget_path(@budget), notice: t("admin.budgets.publish.notice")
  end

  def calculate_winners
    return unless @budget.balloting_process?

    @budget.headings.each { |heading| Budget::Result.new(@budget, heading).delay.calculate_winners }
    redirect_to admin_budget_budget_investments_path(
                  budget_id: @budget.id,
                  advanced_filters: ["winners"]),
                notice: I18n.t("admin.budgets.winners.calculated")
  end

  def switch_group
    redirect_to admin_budget_group_headings_path(@budget, selected_group_id, url_params)
  end

  def update
    if @budget.update(budget_params)
      redirect_to admin_budget_path(@budget), notice: t("admin.budgets.update.notice")
    else
      render :edit
    end
  end

  def create
    @budget = Budget.new(budget_params.merge(published: false))

    if @budget.save
      redirect_to admin_budget_groups_path(@budget, mode: @mode), notice: t("admin.budgets.create.notice")
    else
      render :new
    end
  end

  def destroy
    if @budget.investments.any?
      redirect_to admin_budgets_path, alert: t("admin.budgets.destroy.unable_notice")
    elsif @budget.poll.present?
      redirect_to admin_budgets_path, alert: t("admin.budgets.destroy.unable_notice_polls")
    else
      @budget.destroy!
      redirect_to admin_budgets_path, notice: t("admin.budgets.destroy.success_notice")
    end
  end

  private

    def budget_params
      descriptions = Budget::Phase::PHASE_KINDS.map { |p| "description_#{p}" }.map(&:to_sym)
      valid_attributes = [:phase,
                          :currency_symbol,
                          :voting_style,
                          :main_link_text,
                          :main_link_url,
                          administrator_ids: [],
                          valuator_ids: [],
                          image_attributes: image_attributes
      ] + descriptions
      params.require(:budget).permit(*valid_attributes, *report_attributes, translation_params(Budget))
    end

    def budget_heading_params
      params.require(:heading).permit(:mode) if params.key?(:heading)
    end

    def load_budget
      @budget = Budget.find_by_slug_or_id! params[:id]
    end

    def load_staff
      @admins = Administrator.includes(:user)
      @valuators = Valuator.includes(:user).order(description: :asc).order("users.email ASC")
    end

    def url_params
      @mode.present? ? { mode: @mode } : {}
    end

    def selected_group_params
      params.require(:budget).permit(:group_id) if params.key?(:budget)
    end

    def selected_group_id
      selected_group_params[:group_id]
    end

    def set_budget_mode
      if params[:mode] || budget_heading_params.present?
        @mode = params[:mode] || budget_heading_params[:mode]
      end
    end
end
