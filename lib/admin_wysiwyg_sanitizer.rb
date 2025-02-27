class AdminWYSIWYGSanitizer < WYSIWYGSanitizer
  def allowed_tags
    super + %w[
      h1 iframe object param embed
      i input label form button figure figcaption nav
      section textarea
    ]
  end

  def allowed_attributes
    super + %w[
      min-height longdesc scrolling title allow value
      dir action
      role tabindex type for name title
      data-toggle aria-label aria-hidden allowfullscreen
      data-slider data-initial-start data-end data-slider-handle data-slider-fill
      data-dropdown-menu
      data-magellan data-magellan-target
      data-sticky-container data-sticky data-margin-top data-anchor data-sticky-on
      data-deep-link data-update-history
      data-animation-duration data-animation-easing data-threshold data-active-class data-deep-linking data-update-history data-offset
      data-drilldown
      data-accordion data-accordion-item data-tab-content data-allow-all-closed
      data-accordion-menu
      data-dropdown data-auto-focus placeholder
      data-reveal data-open data-close
      data-tabs aria-selected data-tabs-target data-tabs-content
      data-orbit data-slide data-slide-active-label
      aria-valuenow aria-valuemin aria-valuemax aria-valuetext
      data-tooltip
      data-use-m-u-i
      data-anim-in-from-left data-anim-in-from-right data-anim-out-to-left data-anim-out-to-right
      data-options
      data-equalizer data-equalizer-watch data-equalize-on
      data-target
      data-map data-map-center-latitude data-map-center-longitude data-map-zoom data-admin-editor data-show-admin-shape data-admin-shape data-parent-class data-map-layers
      data-src
      data-path
      data-show-more-text data-show-less-text
      data-pswp-width data-pswp-height
      data-turbolinks
    ]
  end
end
