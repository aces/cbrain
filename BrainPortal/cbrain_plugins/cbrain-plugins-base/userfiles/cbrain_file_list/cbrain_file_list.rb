
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

# Model for a list of CBRAIN files as a plain text CSV file.
#
# The CSV file has a particular list of attributes as defined in
# the constant ATTRIBUTES_LIST ; when an attribute is an ID to
# another model through association, the name of the target
# object is stored in the CSV, not the ID.
#
# Rows can contain placeholders meaning "no file", in that case
# the ID should be 0 (zero) and the remaining attributes left blank.
#
# Only the first column, the ID, is really needed for processing.
# All other columns are there for information only, in particular
# when users want to download the list and reorder the rows or
# zero-out some of them.
#
# There is no header row in the CSV.
#
# Example of file content:
#
#   232123,"myfile.txt",425,"TextFile","MainStoreProvider","jsmith","mygroup"
#   112233,"plan.pdf",3894532,"SingleFile","SomeDP","jsmith","secretproject"
#   0,,,,,,
#   933,"hello.txt",3433434,"TextFile","SomeDP","jsmith","mygroup"
#
class CbrainFileList < CSVFile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # In this model we use the comma as separator, double-quote as quoting character.
  FIELD_SEPARATOR   = ','
  QUOTING_CHARACTER = '"'
  RECORD_TERMINATOR = "\n"

  # Structure of the CSV file; only the ID is used when this object is used as input to something else.
  # When displayed in a web page, the associations to other models are shown by name.
  ATTRIBUTES_LIST   = [ :id, :name, :size, :type, :data_provider_id, :user_id, :group_id ]

  has_viewer :name => 'CBRAIN File List', :partial  => :cb_file_list, :if => :size_allows_viewing_400_000

  def self.pretty_type #:nodoc:
    "CBRAIN List of files"
  end

  def self.file_name_pattern #:nodoc:
    /\.cbcsv\z/i
  end

  # Returns an array of arrays with the parsed content of the CSV file.
  # No validation is done outside of having the proper general format.
  # Entries can contain empty strings or nils.
  #
  #  [ [ 12, "filename1.txt", 2324, "TextFile"  ],
  #    [ "", "",               222, ""          ],
  #    [ 0 , "hello",         8242, "DummyFile" ],
  #    [ 45, "image.jpg",    13121, "ImageFile" ]  ]
  #
  # Note that this method caches internally its result. To clear the
  # cache (if the userfile's content has changed for instance) call
  # the method flush_internal_caches().
  def cached_csv_array
    @rows ||= create_csv_array(QUOTING_CHARACTER, FIELD_SEPARATOR)
  end

  # Sets the internal cache from an explicit +csv_file_content+ string.
  # Returns the same array as cached_csv_array, with the same caveats.
  # This can be invoked before ordered_raw_ids() to bypass the source
  # of the CSV data.
  def load_from_content(csv_file_content)
    flush_internal_caches()
    @rows = CSVFile.parse_file_content_as_csv(csv_file_content, QUOTING_CHARACTER, FIELD_SEPARATOR)
  end

  # Returns an array of the IDs of the first column of the CSV file
  # as extracted by cached_csv_array(). IDs will be numeric, or for
  # missing rows, will contain nils. IDs can be zero.
  #
  #  [ 12, 0, 45, nil, nil, 433 ]
  #
  # Note that this method caches internally its result. To clear the
  # cache (if the userfile's content has changed for instance) call
  # the method flush_internal_caches().
  def ordered_raw_ids
    @ids_with_zeros_and_nils ||= cached_csv_array.map do |row|
      myid = row[0] # can be nil
      if (myid.present?) && (myid =~ /\A\s*\d+\s*\z/)
        myid.strip.to_i
      else
        nil
      end
    end
    @ids_with_zeros_and_nils  # [ 1234, 0, nil, 533, 243, nil, nil ] etc
  end

  # Returns the userfiles accessible to +user+, fetched by ID in the
  # same order as from ordered_raw_ids(). Entries with a numeric ID of 0
  # will be replaced by +missing+, (defaults to nil) and numeric entries pointing
  # to files that are inaccessible to the user will be replaced by +invalid+
  # (also defaults to nil). This method will raise an exception if
  # the content of the CSV file is invalid.
  #
  # Note that this method caches internally its result. To clear the
  # cache (if the userfile's content has changed for instance) call
  # the method flush_internal_caches().
  def userfiles_accessible_by_user!(user, missing=nil, invalid=nil, access_requested = :write)

    # Caching system, since this method is expensive
    @userfiles ||= {}
    cache_key = [user.id,missing,invalid,access_requested]
    return @userfiles[cache_key] if @userfiles[cache_key]

    # Compute everything
    ids_with_zeros_and_nils = self.ordered_raw_ids
    just_ids                = ordered_raw_ids.reject { |v| v.blank? || v == 0 }
    unsorted_files          = Userfile.find_all_accessible_by_user(user, :access_requested => access_requested).where( 'userfiles.id' => just_ids ).all.to_a
    hashed_files            = unsorted_files.index_by { |f| f.id }
    @userfiles[cache_key]   = ids_with_zeros_and_nils.map do |idzn|
      if idzn.nil?
        invalid
      elsif idzn.zero?
        missing
      elsif !hashed_files[idzn]
        invalid
      else
        hashed_files[idzn]
      end
    end

    # Return cached result
    return @userfiles[cache_key]
  end

  # Checks the content of the CSV file and compares the optional attributes
  # to what is found in the userfile described by the ID in the first column.
  # This method will store its warnings and errors in the Rails +errors+
  # for the object. Since we are validating the content of the file, not the
  # Rails attributes, this will not prevent the object from being updated or
  # saved, but it can be used to display information to the user.
  #
  # The errors are stored in +errors+ using keys in the form :row_123 (where
  # 123 is a row number, starting at 0).
  #
  # When +strict+ is true, missing rows (rows with ID set to 0 or empty) will also be
  # checked, and expected to contain empty entries for all other columns; e.g.
  #
  #    0,,,,,,
  #
  # When +strict+ is false, missing rows will not generate any error no matter
  # what the content of the remaining columns.
  #
  # Since a CbrainFileList file can contains thousands of rows, you can limit
  # the number of erroneous rows that are reported using +max_errors+
  #
  # Returns true if no rows were found in error.
  def validate_extra_attributes(as_user = User.admin, max_errors=5, strict=false, access_requested = :write)
    userfiles = userfiles_accessible_by_user!(as_user, nil, "INVALID", access_requested) # sets @rows as side-effect
    @rows.each_with_index do |row,idx|
      break if self.errors.size >= max_errors
      userfile  = userfiles[idx]
      error_key = "row_#{idx}"

      # INVALID ENTRIES
      if userfile.is_a?(String) && userfile == "INVALID"
        self.errors.add(error_key, "has invalid file ID in first column")
        next
      end

      # MISSING ENTRIES
      if userfile.nil? # presumably, ID is zero
        next unless strict
        other_atts = row[1 .. -1].map(&:to_s).join("") # join them all in a single string
        if other_atts.present? # not all blank
          self.errors.add(error_key, "has spurious column values after ID")
        end
        next
      end

      # USERFILE ENTRIES
      bad_message = validate_row_attributes(userfile, row)
      self.errors.add(error_key, bad_message) if bad_message.present?
    end
    self.errors.size == 0
  end

  # Used internally by validate_extra_attributes.
  # +row+ is an array of attributes from the CSV file;
  # the method assumes row[0] contains the proper (and same) ID as +userfile+
  # Returns an error message with the list of bad attributes, or
  # an empty string if all is OK.
  def validate_row_attributes(userfile, row) #:nodoc:
    bad_atts = []
    ATTRIBUTES_LIST.each_with_index do |att,idx|
      next if idx == 0 # skip ID column
      att_no_id    = att.to_s.sub(/_id$/,"")
      val          = row[idx].to_s
      expected_val = userfile.send(att_no_id)
      expected_val = expected_val.try(att == :user_id ? :login : :name).to_s if att.to_s =~ /_id$/
      next if val.to_s == expected_val.to_s
      bad_atts << att_no_id.to_s
    end
    return "" if bad_atts.empty?
    "has column values that do not match: " + bad_atts.map { |a| a.classify.gsub(/(.+)([A-Z])/, '\1 \2') }.join(", ")
  end

  # Many methods of this class cache their result internally
  # to avoid reduplicating costly work. If the content of
  # the CSV file change, calling flush_internal_caches() will
  # clean these caches so they return new, accurate results.
  #
  # Methods that currently cache information are:
  #
  # cached_csv_array, ordered_raw_ids, userfiles_accessible_by_user!
  def flush_internal_caches
    @ids_with_zeros_and_nils = nil
    @userfiles               = nil
    @rows                    = nil
  end

  # Create the plain text of a CSV file representing the CbrainFileList
  # for the array of +userfiles+. nil entries are allowed in +userfiles+
  # and will be properly encoded as missing rows with ID set to 0.
  def self.create_csv_file_from_userfiles(userfiles)
    text_rows           = []
    assoc_cache         = {}
    userfiles.each do |userfile|
      row = []
      if (userfile.nil?)
        row = [0] + Array.new(self::ATTRIBUTES_LIST.size - 1, "")
      else
        self::ATTRIBUTES_LIST.each do |att|
          val = userfile.send(att)  # attribute value in mode; can be an id of an assoc
          if att =~ /_id$/ # try to look up names in other models
            assoc_cache[[att,val]] ||= ( userfile.send(att.to_s.sub(/_id$/,"")).try(att == :user_id ? :login : :name) || "-")
            val = assoc_cache[[att,val]]
          end
          if att !~ /_id$/ && userfile_model_hash[att.to_s].type == :integer ||  userfile_model_hash[att.to_s].type == :decimal # might need to check others too
            row << val
          else
            row << QUOTING_CHARACTER + val.gsub(QUOTING_CHARACTER, QUOTING_CHARACTER+QUOTING_CHARACTER) + QUOTING_CHARACTER
          end
        end
      end
      text_rows << row.join(FIELD_SEPARATOR)
    end
    csv_file = text_rows.join(RECORD_TERMINATOR) + (text_rows.present? ? RECORD_TERMINATOR : "");
    csv_file
  end

  # This is like CbrainFileList.create!() but you must
  # also provide :userfiles among the attributes; these
  # userfiles will be stored as the content of the created
  # CbrainFileList.
  def self.create_with_userfiles!(attributes)
    userfiles = attributes[:userfiles] || cb_error("Need some userfiles for CbrainFileList")
    attlist   = attributes.reject { |k,v| k.to_s == 'userfiles' }
    cbfile    = self.create!(attlist)
    cbfile.set_userfiles(userfiles)
    cbfile
  end

  # Replace the content of the CbrainFileList with a new
  # CbrainFileList representing +userfiles+. The content
  # of the CSV will be immediately uploaded to the provider.
  def set_userfiles(userfiles)
    flush_internal_caches()
    csv = self.class.create_csv_file_from_userfiles(userfiles)
    self.cache_writehandle { |fh| fh.write csv }
    self
  end

  private

  # Can be redefine in sub class
  def self.userfile_model_hash
    Userfile.columns_hash
  end

end
