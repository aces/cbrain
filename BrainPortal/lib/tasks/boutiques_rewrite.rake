
#
# CBRAIN Project
#
# Copyright (C) 2008-2023
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

namespace :cbrain do
  namespace :boutiques do
    desc "Reads a Boutiques descriptor and writes it back with adjustments"

    task :rewrite, [:action] => :environment do |t,args|

      args.with_defaults(:action => 'reorder')
      action = args.action
      raise "This task's action must be 'reorder' (default), or 'pad' or 'pad+reorder'" unless
        action.match /\A(reorder|pad|pad\+reorder)\z/

      # There is no good way to provide standard command line
      # args to a rake task, so I have to butcher ARGV myself.
      args = ARGV.size > 1 ? ARGV[1..ARGV.size-1] : [] # remove 'rake'
      while args.size > 0 && args[0] =~ /^cbrain:boutiques|^-/ # remove options and task name
        args.shift
      end

      # Usage
      if args.size != 1
        puts <<-USAGE
        Usage:
          rake cbrain:boutiques:rewrite              boutiques.json
          rake cbrain:boutiques:rewrite[reorder]     boutiques.json # default
          rake cbrain:boutiques:rewrite[pad]         boutiques.json
          rake cbrain:boutiques:rewrite[pad+reorder] boutiques.json

        This task will read the content of 'boutiques.json' and
        write back 'new_boutiques.json'.

        The single option is a keyword that determines which rewriting
        procedure to perform.

        With 'reorder' (the default), the properties are reordered
        in a pretty way.

        With 'pad', the JSON produced will contain extra spaces to
        align all the values together.

        Unfortunately, because of the way rake tasks work, the
        full path to 'boutiques.json' must be provided, or a
        path relative to CBRAIN's BrainPortal directory.

        USAGE
        exit 1
      end

      filename = args.shift
      pathname = Pathname.new(filename)
      newfile  = pathname.dirname + "new_#{pathname.basename}"

      puts "Reading file #{filename}..."
      btq = BoutiquesSupport::BoutiquesDescriptor.new_from_file(filename)

      if action =~ /reorder/
        puts "Re-ordering..."
        btq = btq.pretty_ordered
        btq.delete('groups') if btq.groups.blank? # stupid btq spec say it must be completely absent
        json = JSON.pretty_generate(btq)
      end

      if action =~ /pad/
        puts "Padding values..."
        btq.delete('groups') if btq.groups.blank? # stupid btq spec say it must be completely absent
        json = btq.super_pretty_json
      end

      puts "Saving #{newfile}..."
      File.open(newfile.to_s,"w") { |fh| fh.write json }

      puts "Done."

    end
  end
end

