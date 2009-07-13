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
class CustomFilter < ActiveRecord::Base
  serialize     :variables
  serialize     :tags
  before_save   :parse_tags
  belongs_to    :user
  
  validates_presence_of   :name
  validates_uniqueness_of :name, :scope  => :user_id
  
  attr_accessor :tag_ids
  attr_writer   :query, :variables
  
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
  def parse_tags
    if self.tag_ids
      self.tags = Tag.find(self.tag_ids).collect{ |t| "tag:#{t.name}" }
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
