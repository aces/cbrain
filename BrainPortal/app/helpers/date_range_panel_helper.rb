
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Helper methods for date range panel.
module DateRangePanelHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Display a panel in order to select a date range,
  # with relative date and absolute date.
  # You can add on which datetime attribute you
  # would perform the filtering.
  # The +options+ hash can contain either or both of the following:
  # [date_attributes]: an array of array each entry contain a datetime and a text.
  # [without_abs]: a boolean used to know if the view displays only relative date.
  def date_range_panel(current_selection = {}, params_name = "date_range", options = {})
    date_attributes         = options[:date_attributes] ||
                              [
                                [:created_at, t('date_range.attributes.by_creation_date')],
                                [:updated_at, t('date_range.attributes.by_update_date')]
                              ]
    without_abs             = options[:without_abs]
    offset_times,
    offset_time_hash,
    adjusted_relative_from,
    adjusted_relative_to    = cache_offsets(current_selection['relative_from'], current_selection['relative_to'])

    render :partial => 'shared/date_range_panel', :locals  => {
           :date_attributes           => date_attributes,
           :without_abs               => without_abs,
           :offset_times              => offset_times,
           :adjusted_relative_from    => adjusted_relative_from,
           :adjusted_relative_to      => adjusted_relative_to,
           :date_attribute            => ["#{params_name}[date_attribute]",            current_selection["date_attribute"]],
           :absolute_or_relative_from => ["#{params_name}[absolute_or_relative_from]", current_selection['absolute_or_relative_from']],
           :absolute_or_relative_to   => ["#{params_name}[absolute_or_relative_to]",   current_selection['absolute_or_relative_to']],
           :relative_from             => ["#{params_name}[relative_from]",             current_selection['relative_from']],
           :relative_to               => ["#{params_name}[relative_to]",               current_selection['relative_to']],
           :absolute_from             => ["#{params_name}[absolute_from]",             current_selection['absolute_from']],
           :absolute_to               => ["#{params_name}[absolute_to]",               current_selection['absolute_to']]
        }
  end

  # Display information about the date range
  def date_range_info(custom_filter)
    offset_times,
    offset_time_hash,
    adjusted_relative_from,
    adjusted_relative_to    = cache_offsets(custom_filter.data_relative_from,
                                            custom_filter.data_relative_to)

    from     = custom_filter.data_absolute_or_relative_from == 'relative' ?
      offset_time_hash[custom_filter.data_relative_from].downcase : custom_filter.data_absolute_from
    to       = custom_filter.data_absolute_or_relative_to   == 'relative' ?
      offset_time_hash[custom_filter.data_relative_to].downcase   : custom_filter.data_absolute_to

    render :partial => 'shared/date_range_info',
           :locals  => {
             :type => custom_filter.data_date_attribute,
             :from => from,
             :to   => to,
            }
  end


  # List of cache update offsets we support
  def cache_offsets(relative_from, relative_to) #:nodoc:
    big_bang = 50.years.to_i # for convenience, because obviously 13.75 billion != 50 ! Fits in signed 32 bits int.

    offset_times =
    [
      [ t('date_range.groups.past_24_hours'),
        [
          [ t('date_range.offsets.right_now'),     0.seconds.to_i.to_s ],
          [ t('date_range.offsets.hours_ago', count: 1),   1.hour.to_i.to_s   ],
          [ t('date_range.offsets.hours_ago', count: 3),   3.hour.to_i.to_s   ],
          [ t('date_range.offsets.hours_ago', count: 6),   6.hour.to_i.to_s   ],
          [ t('date_range.offsets.hours_ago', count: 12), 12.hour.to_i.to_s   ],
        ]
      ],
      [ t('date_range.groups.days'),
        [
          [ t('date_range.offsets.days_ago', count: 1), 1.day.to_i.to_s ],
          [ t('date_range.offsets.days_ago', count: 2), 2.day.to_i.to_s ],
          [ t('date_range.offsets.days_ago', count: 3), 3.day.to_i.to_s ],
          [ t('date_range.offsets.days_ago', count: 4), 4.day.to_i.to_s ],
          [ t('date_range.offsets.days_ago', count: 5), 5.day.to_i.to_s ],
          [ t('date_range.offsets.days_ago', count: 6), 6.day.to_i.to_s ],
        ]
      ],
      [ t('date_range.groups.weeks'),
        [
          [ t('date_range.offsets.weeks_ago', count: 1), 1.weeks.to_i.to_s ],
          [ t('date_range.offsets.weeks_ago', count: 2), 2.weeks.to_i.to_s ],
          [ t('date_range.offsets.weeks_ago', count: 3), 3.weeks.to_i.to_s ],
        ]
      ],
      [ t('date_range.groups.months'),
        [
          [ t('date_range.offsets.months_ago', count: 1), 1.months.to_i.to_s ],
          [ t('date_range.offsets.months_ago', count: 2), 2.months.to_i.to_s ],
          [ t('date_range.offsets.months_ago', count: 3), 3.months.to_i.to_s ],
          [ t('date_range.offsets.months_ago', count: 4), 4.months.to_i.to_s ],
          [ t('date_range.offsets.months_ago', count: 5), 5.months.to_i.to_s ],
          [ t('date_range.offsets.months_ago', count: 6), 6.months.to_i.to_s ],
        ]
      ],
      [ t('date_range.groups.years'),
        [
          [ t('date_range.offsets.years_ago',  count: 1),   1.years.to_i.to_s  ],
          [ t('date_range.offsets.months_ago', count: 18), 18.months.to_i.to_s ],
          [ t('date_range.offsets.years_ago',  count: 2),   2.years.to_i.to_s  ],
          [ t('date_range.offsets.years_ago',  count: 3),   3.years.to_i.to_s  ],
          [ t('date_range.offsets.years_ago',  count: 4),   4.years.to_i.to_s  ],
          [ t('date_range.offsets.years_ago',  count: 5),   5.years.to_i.to_s  ],
          [ t('date_range.offsets.big_bang'),   big_bang.to_s       ]
        ]
      ]
    ]

    offset_time_hash = {}
    offset_times.flatten(2).select{|e| e.size == 2}.map{|dates| offset_time_hash[dates[1]]=dates[0]}

    # Fix the relative values so that they match the closest entries
    # in the offset table above.
    adjusted_relative_from = relative_from.present? ? relative_from.to_i : 1.weeks.to_i
    adjusted_relative_to   = relative_to.to_i

    all_vals   = offset_time_hash.keys

    from_diffs = all_vals.index_by { |v| (v.to_i - adjusted_relative_from).abs }
    adjusted_relative_from = from_diffs[from_diffs.keys.sort { |a,b| a <=> b }.first]

    to_diffs = all_vals.index_by { |v| (v.to_i - adjusted_relative_to).abs }
    adjusted_relative_to = to_diffs[to_diffs.keys.sort { |a,b| a <=> b }.first]

    return [offset_times, offset_time_hash, adjusted_relative_from, adjusted_relative_to]
  end

end
