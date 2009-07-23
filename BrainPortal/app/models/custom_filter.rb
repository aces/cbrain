#
# CBRAIN Project
#
# Custom filter model
#
# Original author: Tarek Sherif 
#
# $Id$
#

#This model represents a user defined filter on Userfile entries.
#A user will select the fields on which to filter, and when the
#CustomFilter is executed an sql query will generated (by the query
#and variables methods) which can be used as a condition parameter
#for +finds+ done by the Userfile resource.
#
#=Attributes:
#[*name*] A string representing the name of the filter.
#[*file_name_type*] The type of filtering done on the filename (+matches+, <tt>begins with</tt>, <tt>ends with</tt> or +contains+).
#[*file_name_term*] The string or substring to search for in the filename.
#[*created_date_type*] The type of filtering done on the creation date (+before+, +on+ or +after+).
#[*created_date_term*] The date to filter against.
#[*size_type*] The type of filtering done on the file size (>, < or =).
#[*size_term*] The file size to filter against.
#[*group_id*] The id of the group to filter on.
#[*tags*] A serialized hash of tags to filter on.
#= Associations:
#*Belongs* *to*:
#* User
class CustomFilter < ActiveRecord::Base
      
  belongs_to    :user
  
  serialize     :tags
  
  validates_presence_of   :name
  validates_uniqueness_of :name, :scope  => :user_id
  validates_format_of     :name,  :with => /^[\w\-\=\.\+\?\!\s]*$/, 
                                  :message  => 'only the following characters are valid: alphanumeric characters, spaces, _, -, =, +, ., ?, !'
  validates_numericality_of :size_term, :allow_nil  => true
  
  attr_accessor   :tag_ids
  attr_writer   :query, :variables
  
  before_save   :prepare_tags
  
  Revision_info="$Id$"
  
  #Returns the sql query to be executed by the filter.
  #
  #*Example*: If the filter is meant to collect userfiles with a name containing
  #the substring +sub+, the variables method will return the following string:
  #  "(userfiles.name LIKE ?)"
  #The value to be interpolated in place of the '?' (i.e. "%sub%" in this case)
  #is returned by the variables method.
  def query
    if @query.blank?
      parse_query
    end
    @query
  end
  
  #Returns an array of the values to be interpolated into the query string.
  #
  #*Example*: If the filter is meant to collect userfiles with a name containing
  #the substring +sub+, the query method will return the following array:
  #  ["%sub%"]
  #The query string itself is returned by the query method.
  def variables
    if @variables.blank?
      parse_query
    end
    @variables
  end
  
  private
  
  #Converts the filters attributes into an sql query
  #which can be constructed using the query and variables methods.
  def parse_query    
    @query ||= ""
    @variables ||= []
    
    parse_name_query unless self.file_name_type.blank? || self.file_name_term.blank?
    parse_created_date_query unless self.created_date_type.blank? || self.created_date_term.blank?
    parse_size_query unless self.size_type.blank? || self.size_term.blank?
    parse_group_query unless self.group_id.blank?
  end
  
  #Convert tag_ids attribute into an array of tag filters (format: "tag:<tag_name>").
  def prepare_tags
    if self.tag_ids
      self.tags = Tag.find(self.tag_ids).collect{ |tag| "#{tag.name}"}
    else
      self.tags = []
    end
  end
  
  #Contruct the portion of the filter query which functions on 
  #the Userfile entry's name.
  def parse_name_query
    query = 'userfiles.name'
    term = self.file_name_term
    if self.file_name_type == 'match'
      query += ' = ?'
    else
      query += ' LIKE ?'
    end
    
    if self.file_name_type == 'contain' || self.file_name_type == 'begin'
      term += '%'
    end
    
    if self.file_name_type == 'contain' || self.file_name_type == 'end'
      term = '%' + term
    end
    
    @query += " AND " unless @query.blank?
    @query += "(#{query})"
    @variables << term
  end
  
  #Contruct the portion of the filter query which functions on 
  #the Userfile entry's creation date.
  def parse_created_date_query
    query = "DATE(userfiles.created_at) #{self.created_date_type} ?"
    term = self.created_date_term
    
    @query += " AND " unless @query.blank?
    @query += "(#{query})"
    @variables << term
  end
  
  #Contruct the portion of the filter query which functions on 
  #the Userfile entry's size.
  def parse_size_query
    query = "userfiles.size #{self.size_type} ?"
    term = (self.size_term.to_i * 1000).to_s  
    
    @query += " AND " unless @query.blank?
    @query += "(#{query})"
    @variables << term
  end
  
  #Contruct the portion of the filter query which functions on 
  #the Userfile entry's group ownership.
  def parse_group_query
    query = "userfiles.group_id = ?"
    term = self.group_id
    
    @query += " AND " unless @query.blank?
    @query += "(#{query})"
    @variables << term
  end
end
