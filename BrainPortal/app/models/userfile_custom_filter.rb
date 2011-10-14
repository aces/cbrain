#
# CBRAIN Project
#
# Custom filter model
#
# Original author: Tarek Sherif 
#
# $Id$
#

#Subclass of CustomFilter representing custom filters for the Userfile resource.
#
#=Parameters filtered:
#[*file_name_type*] The type of filtering done on the filename (+matches+, <tt>begins with</tt>, <tt>ends with</tt> or +contains+).
#[*file_name_term*] The string or substring to search for in the filename.
#[*created_date_type*] The type of filtering done on the creation date (+before+, +on+ or +after+).
#[*created_date_term*] The date to filter against.
#[*size_type*] The type of filtering done on the file size (>, < or =).
#[*size_term*] The file size to filter against.
#[*group_id*] The id of the group to filter on.
#[*tags*] A serialized hash of tags to filter on.
class UserfileCustomFilter < CustomFilter
                          
  Revision_info=CbrainFileRevision[__FILE__]
  
  #See CustomFilter
  def filter_scope(scope)
    scope = scope_name(scope)  unless self.data["file_name_type"].blank? || self.data["file_name_term"].blank?
    scope = scope_date(scope)  unless self.data["date_attribute"].blank?
    scope = scope_size(scope)  unless self.data["size_type"].blank? || self.data["size_term"].blank?
    scope = scope_user(scope)  unless self.data["user_id"].blank?
    scope = scope_group(scope) unless self.data["group_id"].blank?
    scope = scope_dp(scope)    unless self.data["data_provider_id"].blank?
    scope = scope_type(scope)  unless self.data["type"].blank?
    scope
  end

  #Return table name for SQL filtration 
  def target_filtered_table
    "userfiles"
  end
  
  #Virtual attribute for assigning tags to the data hash.
  def tag_ids=(ids)
    self.data["tag_ids"] = Tag.find(ids).collect{ |tag| "#{tag.id}"}
  end
  
  #Convenience method returning only the tags in the data hash.
  def tag_ids
    self.data["tag_ids"] || []
  end
  
  #Convenience method returning only the date_term in the data hash.
  def date_term
    self.data["date_term"]
  end
  
  #Virtual attribute for assigning the data_term to the data hash.
  def date_term=(date)
    self.data["date_term"] = "#{date["date_term(1i)"]}-#{date["date_term(2i)"]}-#{date["date_term(3i)"]}"
  end
  
  private
  
  #Return +scope+ modified to filter the Userfile entry's name.
  def scope_name(scope)
    query = 'userfiles.name'
    term = self.data["file_name_term"]
    if self.data["file_name_type"] == 'match'
      query += ' = ?'
    else
      query += ' LIKE ?'
    end
    
    if self.data["file_name_type"] == 'contain' || self.data["file_name_type"] == 'begin'
      term += '%'
    end
    
    if self.data["file_name_type"] == 'contain' || self.data["file_name_type"] == 'end'
      term = '%' + term
    end
    
    scope.where( ["#{query}", term] )
  end
  
  #Return +scope+ modified to filter the Userfile entry's size.
  def scope_size(scope)
    scope.where( ["userfiles.size #{inequality_type(self.data["size_type"])} ?", (self.data["size_term"].to_f * 1000)])
  end
  
  #Return +scope+ modified to filter the Userfile entry's owner.
  def scope_user(scope)
    scope.where( ["userfiles.user_id = ?", self.data["user_id"]])
  end
  
  #Return +scope+ modified to filter the Userfile entry's group ownership.
  def scope_group(scope)
    scope.where( ["userfiles.group_id = ?", self.data["group_id"]])
  end
  
  #Return +scope+ modified to filter the Userfile entry's data provider.
  def scope_dp(scope)
    scope.where( ["userfiles.data_provider_id = ?", self.data["data_provider_id"]])
  end
  
  #Return +scope+ modified to filter the Userfile entry's type.
  def scope_type(scope)
    scope.where( :type  =>  self.data["type"] )
  end
  
end
