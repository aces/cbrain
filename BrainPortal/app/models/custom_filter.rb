#
# CBRAIN Project
#
# Custom filter model
#
# Original author: Tarek Sherif 
#
# $Id$
#

class CustomFilter < ActiveRecord::Base
  serialize     :variables
  serialize     :tags
  before_save   :parse_tags
  belongs_to    :user
  
  validates_presence_of   :name
  validates_uniqueness_of :name, :scope  => :user_id
  
  attr_accessor :tag_ids
  attr_writer   :query, :variables
    
  # def created_date_term=(date)
  #   if date.is_a? Array
  #     year  = date[0]
  #     month = date[1]
  #     day   = date[2]
  #     @created_date_term = "#{year}-#{month}-#{day}"
  #   else
  #     @created_date_term = nil
  #   end
  # end
  
  def query
    if @query.blank?
      parse_query
    end
    @query
  end
  
  def variables
    if @variables.blank?
      parse_query
    end
    @variables
  end
  
  private
  
  def parse_query    
    @query ||= ""
    @variables ||= []
    
    parse_name_query unless self.file_name_type.blank? || self.file_name_term.blank?
    parse_created_date_query unless self.created_date_type.blank? || self.created_date_term.blank?
    parse_size_query unless self.size_type.blank? || self.size_term.blank?
    parse_group_query unless self.group_id.blank?
  end
  
  def parse_tags
    if self.tag_ids
      self.tags = Tag.find(self.tag_ids).collect{ |t| "tag:#{t.name}" }
    else
      self.tags = []
    end
  end
  
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
  
  def parse_created_date_query
    query = "DATE(userfiles.created_at) #{self.created_date_type} ?"
    term = self.created_date_term
    
    @query += " AND " unless @query.blank?
    @query += "(#{query})"
    @variables << term
  end
  
  def parse_size_query
    query = "userfiles.size #{self.size_type} ?"
    term = (self.size_term.to_i * 1000).to_s  
    
    @query += " AND " unless @query.blank?
    @query += "(#{query})"
    @variables << term
  end
  
  def parse_group_query
    query = "userfiles.group_id = ?"
    term = self.group_id
    
    @query += " AND " unless @query.blank?
    @query += "(#{query})"
    @variables << term
  end
end
