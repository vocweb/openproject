# frozen_string_literal: true

module WorkPackages
  module DatePicker
    class DialogContentComponent < ApplicationComponent
      include OpPrimer::ComponentHelpers
      include OpTurbo::Streamable

      AUTOMATIC_MODE = "automatic"
      MANUAL_MODE = "manual"

      def initialize(work_package:, mode: MANUAL_MODE)
        super

        @work_package = work_package
        @mode = mode
      end

      private

      def manually_scheduled?
        @work_package.schedule_manually
      end

      def show_banner?
        true # TODO
      end

      def banner_scheme
        manually_scheduled? ? :warning : :default
      end

      def banner_link
        gantt_index_path(
          query_props: {
            c: %w[id subject type status assignee project startDate dueDate],
            tll: '{"left":"startDate","right":"subject","farRight":null}',
            tzl: "auto",
            t: "id:asc",
            tv: true,
            hi: true,
            f: [
              { "n" => "id", "o" => "=", "v" => all_relational_wp_ids }
            ]
          }.to_json.freeze
        )
      end

      def banner_title
        if manually_scheduled?
          I18n.t("work_packages.datepicker_modal.banner.title.manually_scheduled")
        elsif children.any?
          I18n.t("work_packages.datepicker_modal.banner.title.automatic_with_children")
        elsif predecessor_relations.any?
          I18n.t("work_packages.datepicker_modal.banner.title.automatic_with_predecessor")
        end
      end

      def banner_description
        if manually_scheduled?
          if children.any?
            return I18n.t("work_packages.datepicker_modal.banner.description.manual_with_children")
          elsif predecessor_relations.any?
            if overlapping_predecessor?
              return I18n.t("work_packages.datepicker_modal.banner.description.manual_overlap_with_predecessors")
            elsif predecessor_with_large_gap?
              return I18n.t("work_packages.datepicker_modal.banner.description.manual_gap_between_predecessors")
            end
          end
        end

        I18n.t("work_packages.datepicker_modal.banner.description.click_on_show_relations_to_open_gantt",
               button_name: I18n.t("js.work_packages.datepicker_modal.show_relations"))
      end

      def overlapping_predecessor?
        predecessor_work_packages.any? { |wp| wp.due_date.after?(@work_package.start_date) }
      end

      def predecessor_with_large_gap?
        sorted = predecessor_work_packages.sort_by(&:due_date)
        sorted.last.due_date.before?(@work_package.start_date - 2)
      end

      def predecessor_relations
        @predecessor_relations ||= @work_package.follows_relations
      end

      def predecessor_work_packages
        @predecessor_work_packages ||= predecessor_relations
                                         .includes(:to)
                                         .map(&:to)
      end

      def children
        @children ||= @work_package.children
      end

      def all_relational_wp_ids
        @work_package
          .relations
          .pluck(:from_id, :to_id)
          .flatten
          .uniq
      end
    end
  end
end
