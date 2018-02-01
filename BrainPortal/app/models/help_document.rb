
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

require 'fileutils'

# Simple model representing available documentation (help) pages
# in Markdown format.
#
# =Attributes
# [*key*]  Arbitrary unique string identifier of a doc page. For example,
#          generic documentation on data providers could have a key of
#          'data_provider' while documentation on creating data providers
#          could have a key of 'data_provider/create'.
# [*path*] Relative path inside {Rails.root}/public/doc where
#          documentation is kept.
#
# TODO auto-generate an HelpDocument if theres a file in PATH matching the key
class HelpDocument < ApplicationRecord

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_save    :write_doc
  before_destroy :remove_doc

  validates      :key,  :presence => true, :uniqueness => true
  validates      :path, :presence => true, :subpath_format => true

  attr_readonly  :key, :path

  # Directory where documentation is stored
  PATH = Rails.root + "public/doc"

  # Full path to the help document file
  def full_path
    HelpDocument::PATH + path
  end

  # Pseudo-attribute representing the document's contents
  def contents
    @contents ||= (File.file?(self.full_path) ? IO.read(self.full_path) : nil)
  end

  def contents=(contents) #:nodoc:
    @contents = contents
  end

  # If +user+ can edit the documentation
  def self.can_edit?(user)
    user.has_role?(:core_admin)
  end

  # Try to create a new HelpDocument with key +key+ from an existing file at
  # +subpath+. If +subpath+ is not given, it is generated from +key+ using
  # path_from_key.
  # NOTE: The new HelpDocument is right away saved to persistent storage, as
  # to be used subsequently in help buttons.
  def self.from_existing_file!(key, path = nil)
    path ||= path_from_key(key)
    return nil unless File.file?(HelpDocument::PATH + path)

    # FIXME Inefficient; the file is re-written in the before_save callback.
    doc          = self.new(:key => key, :path => path);
    doc.contents = IO.read(doc.full_path)
    doc.save!
    doc
  end

  # Generate a sensible documentation file subpath from +key+
  def self.path_from_key(key)
    key.delete("~.") + ".md"
  end

  private

  # Write @contents to the document's file at full_path. Called when the
  # HelpDocument record is saved to persistent storage.
  def write_doc
    doc_path = self.full_path
    doc_dir  = doc_path.dirname

    if @contents
      FileUtils.mkpath(doc_dir) unless File.file?(doc_path) || File.directory?(doc_dir)
      IO.write(doc_path, @contents)
    else
      File.unlink(doc_path) if File.file?(doc_path)
    end
  end

  # Remove the document's file at full_path. Called when the HelpDocument
  # record is destroyed.
  # FIXME should empty directories be removed as well?
  def remove_doc
    File.unlink(self.full_path) rescue nil
  end
end
