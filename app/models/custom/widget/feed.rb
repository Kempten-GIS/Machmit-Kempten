require_dependency Rails.root.join("app", "models", "widget", "feed").to_s

class Widget::Feed < ApplicationRecord
  KINDS = %w[active_projekts polls proposals debates expired_projekts investment_proposals].freeze

  def active_projekts(current_user)
    Projekt.show_in_homepage.index_order_underway
      .select { |p| p.visible_for?(current_user) }.first(limit)
  end

  def expired_projekts(current_user)
    Projekt.show_in_homepage.index_order_expired
      .select { |p| p.visible_for?(current_user) }.first(limit)
  end

  def polls
    Poll.current.where(show_on_home_page: true).order(created_at: :asc)
  end

  def proposals
    Proposal.published.not_archived.with_current_projekt.sort_by_created_at
  end

  def debates
    Debate.with_current_projekt.sort_by_created_at
  end

  def investment_proposals
    Budget::Investment.joins(:budget).where.not(budgets: { projekt_id: nil }).sort_by_created_at.limit(limit)
  end

  def self.by_kind(kind)
    find{ |feed| feed.kind == 'expired_projekts' }
  end
end
