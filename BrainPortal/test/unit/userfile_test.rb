require 'test_helper'

class UserfileTest < ActiveSupport::TestCase
  # Replace this with your real tests
  fixtures :userfiles, :users, :tags, :data_providers
  
  def test_should_not_allow_same_userfile_for_same_user
    t = SingleFile.new(:name  => 'file', :user_id  => 1)
    give_data_provider_id(t)
    assert t.save, "Couldn't save new file"
    t2 = SingleFile.new(:name  => 'file', :user_id  => 1)
    give_data_provider_id(t2)
    assert !t2.save, "Saved a non-unique file to same user."
  end
  
  def test_should_allow_same_userfile_for_different_users
    t = SingleFile.new(:name  => 'file', :user_id  => 1)
    give_data_provider_id(t)
    assert t.save, "Couldn't save new file"
    t2 = SingleFile.new(:name  => 'file', :user_id  => 2)
    give_data_provider_id(t2)
    assert t2.save, "Couldn't save same file to different user."
  end
  
  def test_filter_names
    assert_equal Userfile.get_filter_name('jiv', nil), 'file:jiv'
    assert_equal Userfile.get_filter_name('minc', nil), 'file:minc'
    assert_equal Userfile.get_filter_name('name_search', 'hello'), 'name:hello'
    assert_equal Userfile.get_filter_name('tag_search', 'hello'), 'tag:hello'  
  end
  
  # def test_filter_to_sql
  #   filters = ['file:minc']
  #   assert_equal Userfile.convert_filters_to_sql_query(filters), ["(userfiles.name LIKE ?)", '%.mnc']
  #   filters << 'name:hello'
  #   assert_equal Userfile.convert_filters_to_sql_query(filters), 
  #                   ["(userfiles.name LIKE ?) AND (userfiles.name LIKE ?)", '%.mnc', '%hello%']
  #   filters << 'file:jiv'
  #   assert_equal Userfile.convert_filters_to_sql_query(filters), 
  #                   ["(userfiles.name LIKE ?) AND (userfiles.name LIKE ?) AND (userfiles.name LIKE ? OR userfiles.name LIKE ? OR userfiles.name LIKE ?)",
  #                      '%.mnc', '%hello%', "%.raw_byte", "%.raw_byte.gz", "%.header"]
  # end
  
  # def test_sql_queries
  #     filters = ['file:minc']
  #     assert Userfile.find(:all, :conditions => Userfile.convert_filters_to_sql_query(filters)).all?{|file| file.name =~ /.*\.mnc$/}
  #     filters << 'name:e'
  #     assert Userfile.find(:all, :conditions => Userfile.convert_filters_to_sql_query(filters)).all?{|file| file.name =~ /.*\.mnc$/ && file.name =~ /e/}
  #   end
  
  def test_tag_filtering
    filter1 = 'tag:' + Tag.first.name
    files = Userfile.all
    assert Userfile.apply_tag_filters(files, [filter1]).all?{ |file|  file.tags.any?{ |t|  t == Tag.first }}
    filter2 = 'tag:' + Tag.last.name
    assert Userfile.apply_tag_filters(files, [filter1, filter2]).all?{ |file|  file.tags.any?{ |t|  t == Tag.first }}
  end
  
  def test_set_order
    order = 'name'
    order = Userfile.set_order('name', order)
    assert_equal order, 'name DESC'
    order = Userfile.set_order('name', order)
    assert_equal order, 'name'
    
    order = Userfile.set_order('size', order)
    assert_equal order, 'type, size'
    order = Userfile.set_order('size', order)
    assert_equal order, 'type, size DESC'
    
    order = Userfile.set_order('lft', order)
    assert_equal order, 'lft'
    order = Userfile.set_order('lft', order)
    assert_equal order, 'lft'
  end

  def give_data_provider_id(userfile)
    return if userfile.data_provider_id
    unless self.instance_variable_defined?('@prov_id')
      prov = DataProvider.find_by_name("TestVault") || DataProvider.first
      @prov_id = prov.id
    end
    userfile.data_provider_id = @prov_id
  end

end
