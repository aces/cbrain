
# Helper methods for tasks views.

module TasksHelper

  Revision_info="$Id$"

  # Shows a bent-arrow character indented by +level+ 'spaces'
  # (actually, four NBSPs per level)
  def task_tree_view_icon(level)
    ('&nbsp' * 4 * level) + '&#x21b3;'
  end

end

