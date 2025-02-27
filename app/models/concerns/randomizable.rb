module Randomizable
  extend ActiveSupport::Concern

  class_methods do
    def sort_by_random(seed = rand(10_000_000))
      ids = order(:id).ids.uniq.shuffle(random: Random.new(seed))

      return all if ids.empty?

      ids_with_order = ids.map.with_index { |id, order| "(#{id}, #{order})" }.join(", ")

      joins("LEFT JOIN (VALUES #{ids_with_order}) AS ids(id, ordering) ON #{table_name}.id = ids.id")
        .order("ids.ordering")
    end

    def perform_sort_by(order, seed)
      if order == "random"
        send("sort_by_#{order}", seed)
      else
        send("sort_by_#{order}")
      end
    end
  end
end
