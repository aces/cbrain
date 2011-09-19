#
# CBRAIN Project
#
# Custom filter model
#
# Original author: Tarek Sherif 
#
# $Id$
#

#Subclass of CustomFilter representing custom filters for the CbrainTask resource
#(which are controlled by the tasks contoller).
#
#=Parameters filtered:
#[*type*] The CbrainTask subclass to filter.
#[*description*] The CbrainTask description to filter.
#[*created_date_type*] The type of filtering done on the creation date (+before+, +on+ or +after+).
#[*created_date_term*] The date to filter against.
#[*user_id*] The user_id of the CbrainTask owner to filter against.
#[*bourreau_id*] The bourreau_id of the bourreau to filter against.
class TaskCustomFilter < CustomFilter
                          
  Revision_info=CbrainFileRevision[__FILE__]
  
  #See CustomFilter
  def filter_scope(scope)
    scope = scope_type(scope)         unless self.data["type"].blank?
    scope = scope_description(scope)  unless self.data["description_type"].blank? || self.data["description_term"].blank?
    scope = scope_user(scope)         unless self.data["user_id"].blank?
    scope = scope_bourreau(scope)     unless self.data["bourreau_id"].blank?
    scope = scope_date(scope)         unless self.data["date_attribute"].blank?
    scope = scope_status(scope)       unless self.data["status"].blank?
    scope
  end

  #Return table name for SQL filtration 
  def target_filtered_table
    "cbrain_tasks"
  end
  
  #Convenience method returning only the created_date_term in the data hash.
  def created_date_term
    self.data["created_date_term"]
  end
  
  #Virtual attribute for assigning the data_term to the data hash.
  def created_date_term=(date)
    self.data["created_date_term"] = "#{date["created_date_term(1i)"]}-#{date["created_date_term(2i)"]}-#{date["created_date_term(3i)"]}"
  end

  private

  #Return +scope+ modified to filter the CbrainTask entry's type.
  def scope_type(scope)
    return scope if self.data["type"].is_a?(Array) && self.data["type"].all? { |v| v.blank? }
    scope.scoped(:conditions  => {:type  =>  self.data["type"]})
  end
  
  #Return +scope+ modified to filter the CbrainTask entry's description.
  def scope_description(scope)
    query = 'cbrain_tasks.description'
    term = self.data["description_term"]
    if self.data["description_type"] == 'match'
      query += ' = ?'
    else
      query += ' LIKE ?'
    end
    
    if self.data["description_type"] == 'contain' || self.data["description_type"] == 'begin'
      term += '%'
    end
    
    if self.data["description_type"] == 'contain' || self.data["description_type"] == 'end'
      term = '%' + term
    end
    
    scope.scoped(:conditions  => ["#{query}", term])
  end
  
  #Return +scope+ modified to filter the CbrainTask entry's owner.
  def scope_user(scope)
    scope.scoped(:conditions  => ["cbrain_tasks.user_id = ?", self.data["user_id"]])
  end
  
  #Return +scope+ modified to filter the CbrainTask entry's bourreau.
  def scope_bourreau(scope)
    scope.scoped(:conditions  => ["cbrain_tasks.bourreau_id = ?", self.data["bourreau_id"]])
  end

  def scope_status(scope)
    return scope if self.data["status"].is_a?(Array) && self.data["status"].all? { |v| v.blank? }
    scope.scoped(:conditions => {:status => self.data["status"]})
  end
  
end
