# frozen_string_literal: true

class Projekts::ProjektEvents::ListItemNewComponent < ApplicationComponent
  delegate :render_image, to: :helpers

  attr_reader :projekt_event

  def initialize(projekt_event:, show_projekt_link: false)
    @projekt_event = projekt_event
    @show_projekt_link = show_projekt_link
  end
end
