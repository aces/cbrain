#
# CBRAIN Project
#
# Custom filter model
#
# Original author: Tarek Sherif 
#
# $Id$
#

#Subclass of CustomFilter representing custom filters for the DrmaaTask resource
#(which are controlled by the tasks contoller).
#
#=Parameters filtered:
#[*type*] The DrmaaTask subclass to filter.
#[*description*] The DrmaaTask description to filter.
#[*created_date_type*] The type of filtering done on the creation date (+before+, +on+ or +after+).
#[*created_date_term*] The date to filter against.
#[*user_id*] The user_id of the DrmaaTask owner to filter against.
#[*bourreau_id*] The bourreau_id of the bourreau to filter against.
class TaskCustomFilter < CustomFilter
                          
  Revision_info="$Id$"
  
  #See CustomFilter
  def filter_scope(scope)
    scope = scope_type(scope)         unless self.data["type"].blank?
    scope = scope_description(scope)  unless self.data["description_type"].blank? || self.data["description_term"].blank?
    scope = scope_user(scope)         unless self.data["user_id"].blank?
    scope = scope_bourreau(scope)     unless self.data["bourreau_id"].blank?
    scope = scope_created_date(scope) unless self.data["created_date_type"].blank? || self.data["created_date_term"].blank?
    scope
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
  
  #Return +scope+ modified to filter the DrmaaTask entry's type.
  def scope_type(scope)
    scope.scoped(:conditions  => {:type  =>  self.data["type"]})
  end
  
  #Return +scope+ modified to filter the DrmaaTask entry's description.
  def scope_description(scope)
    query = 'drmaa_tasks.description'
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
  
  #Return +scope+ modified to filter the DrmaaTask entry's owner.
  def scope_user(scope)
    scope.scoped(:conditions  => ["drmaa_tasks.user_id = ?", self.data["user_id"]])
  end
  
  #Return +scope+ modified to filter the DrmaaTask entry's bourreau.
  def scope_bourreau(scope)
    scope.scoped(:conditions  => ["drmaa_tasks.bourreau_id = ?", self.data["bourreau_id"]])
  end
  
  #Return +scope+ modified to filter the DrmaaTask entry's created_at date.
  def scope_created_date(scope)
    scope.scoped(:conditions  => ["DATE(drmaa_tasks.created_at) #{self.data["created_date_type"]} ?", self.data["created_date_term"]])
  end
end
