
class ApprovalResult
   attr_accessor :diagnostics, :plain_password

   def to_s
     self.diagnostics.presence.to_s
   end

end

class Demand < ActiveRecord::Base

#    t.string   "title"
#    t.string   "first"
#    t.string   "middle"
#    t.string   "last"
#    t.string   "institution"
#    t.string   "department"
#    t.string   "position"
#    t.string   "email"
#    t.string   "street1"
#    t.string   "street2"
#    t.string   "city"
#    t.string   "province"
#    t.string   "country"
#    t.string   "postal_code"
#    t.string   "time_zone"
#    t.string   "service"
#    t.string   "login"
#    t.string   "comment"
#
#    t.string   "session_id"
#    t.string   "confirm_token"
#    t.boolean  "confirmed"
#
#    t.string   "approved_by"
#    t.datetime "approved_at"
#    t.datetime "created_at"
#    t.datetime "updated_at"

  validate              :strip_blanks

  attr_accessible       :title, :first, :middle, :last,
                        :institution, :department, :position, :email,
                        :street1, :street2, :city, :province, :country, :postal_code,
                        :service, :login, :time_zone, :comment

  validates_presence_of :first, :last,
                        :institution, :department, :position, :email,
                        :city, :province, :country,
                        :service, :confirm_token

  validates             :login, :length => { :minimum => 3, :maximum => 20 },     :allow_blank => true
  validates             :login, :format => { :with => /^[a-zA-Z][a-zA-Z0-9]+$/ }, :allow_blank => true

  validates             :email, :format => { :with => /^(\w[\w\-\.]*)@(\w[\w\-]*\.)+[a-z]{2,}$|^\w+@localhost$/i }

  #validates_length_of   :postal_code, :within => 5..10

  OK_COUNTRIES_LIST = [
   "Afganistan", "Albania", "ALGERIA",  "ANDORRA",   "Argentina",   "Australia",  "austria", "Azerbaijan",
   "Belarus",   "Belgique", "Belgium",    "Bolivia",   "Brasil", "Brazil",  "Brunei", "Bulgaria",
   "CA",  "Cambodia", "CAMEROON", "Canada",     "Chile", "China",  "Colombia", "Costa Rica", "Cuba",   "Cyprus", "Czech Republic",
   "Danmark",   "Denmark", "Deutschland",   "Dominican Republic",  "Dutch Caribbean",
   "ecuador", "egypt", "el salvador", "England", "Estonia", "Ethiopia",
   "Finland",  "France",  "Georgia", "Germany", "Greece",  "Guatemala",  "holland", "Honduras", "Hong Kong",   "Hungary",
   "Iceland", "India", "Indonesia",  "Iran", "Iraq", "Ireland",  "Israel", "Italia", "Italy",
   "Japan",  "Kazakhstan", "Kenya",  "Korea",  "Kuwait",  "Latvia", "Lebanon",  "Liechtenstein",  "Lithuania",  "Luxembourg",
   "Macau", "Madrid",  "Malaysia", "mali", "Malta",  "maroc", "Martinique",   "Mexico",  "Moldova", "montevideo",   "Morocco",
   "Nederland",   "Nepal", "Netherland", "Netherlands",      "New Zealand", "Nicaragua",  "Nigeria",  "Northern Ireland", "Norway",
   "Oman",  "Pakistan",  "Paraguay",   "Peru",  "Philippines", "Poland", "Polska",  "Portugal",  "Puerto Rico",  "Qatar",
   "Republic of Korea",  "Romania",   "Russia",   "Russian Federation", "Rwanda",
   "Saudi Arabia",  "Schweiz", "Scotland",  "Serbia",   "Singapore",  "Slovakia", "Slovenia", "South Africa", "south korea", "Spain", "sri lanka",  "St. Maarten",  "Suisse", "Suriname", "Sweden", "Switzerland",
   "Taiwan",  "Thailand",  "The Netherlands", "Trinidad and Tobago",   "Tunisia", "turkey",
   "U. S. A.", "U.K.", "U.S.", "U.S.A.", "UAE", "UK", "Ukraine",  "United Arab Emirates", "United Kingdom",    "United States", "United States of America",  "Uruguay", "US", "USA",
   "Venezuela",  "Vietnam",  "Wales"
  ]
  OK_COUNTRIES_HASH = {}; OK_COUNTRIES_LIST.each { |c| OK_COUNTRIES_HASH[c.downcase]=true }


  def strip_blanks
    [
      :title, :first, :middle, :last,
      :institution, :department, :position, :email,
      :street1, :street2, :city, :province, :country, :postal_code,
      :service, :login, :comment
    ].each do |att|
      val = read_attribute(att) || ""
      write_attribute(att, val.strip)
    end
    self.login = (self.login.presence || "").downcase
    true
  end

  def generate_token
    tok = ""
    20.times { c=sprintf("%d",rand(10)); tok += c }
    self.confirm_token = tok
  end

  def full
    "#{title} #{first} #{middle} #{last}".strip.gsub(/  +/, " ")
  end

  def approved?
    self.approved_by.present? && self.approved_at.present?
  end

  def is_suspicious?  # types: 1=warning, 2=weird_entries, 3=keyboard_banging
    country = (self.country.presence || "").downcase
    full_cat = "#{full_name}|#{institution}|#{department}|#{email}|#{country}|#{province}|#{city}|#{postal_code}|#{street1}|#{street2}|#{comment}|#{login}".downcase
    return 3 if full_cat =~ /qwe|tyu|uio|asd|sdf|dfg|fgh|hjk|jkl|zxc|xcv|cvb|vbn|bnm/i # keyboard banging
    return 3 if full_cat =~ /shit|fuck|cunt|blah|piss|vagina|mother|nigg|negro/i # obscenities
    return 3 if full_cat =~ /([a-z])\1\1\1/i
    return 2 if first.downcase == last.downcase || first.downcase == middle.downcase || middle.downcase == last.downcase
    return 2 if first.downcase !~ /[a-z]/i || last.downcase !~ /[a-z]/i
    return 1 unless OK_COUNTRIES_HASH[country]
    nil
  end

  alias full_name full

  def self.uniq_login_cnts
    login_cnts = {}
    Demand.select(:login).all.each { |d| e=d.login.downcase;login_cnts[e] ||= 0;login_cnts[e] += 1 }
    login_cnts
  end

  def self.uniq_email_cnts
    email_cnts = {}
    Demand.select(:email).all.each { |d| e=d.email.downcase;email_cnts[e] ||= 0;email_cnts[e] += 1 }
    email_cnts
  end

  def after_approval
    #puts "Approving: #{self.full}"
    chars = (('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a).shuffle.reject { |c| c =~ /[01OolI]/ }
    salt  = chars[0] + chars[1]
    password = ""
    12.times { password += chars[rand(chars.size)] }

    mylogin = self.login.presence || (self.first[0,1] + self.last).downcase
    self.login = mylogin
    unless self.valid?
       raise "Current record is invalid. Probably: login name incorrect. Check form values."
    end

    #att = {
    #  "full_name"             => self.full,
    #  "login"                 => self.login,
    #  "email"                 => self.email,
    #  "city"                  => self.city,
    #  "country"               => self.country,
    #  "time_zone"             => self.time_zone,
    #  "type"                  => 'NormalUser',
    #  "password"              => password,
    #  "password_confirmation" => password,
    #  "password_reset"        => true,
    #  }

    u = User.new
    u.full_name = self.full
    u.login = self.login
    u.email = self.email
    u.city = self.city
    u.country = self.country
    u.time_zone = self.time_zone
    u.type = 'NormalUser'
    u.password = password
    u.password_confirmation = password
    u.password_reset = true

    if u.save()
      uid = u.id
    else
      raise "Could not create user"
    end

    #agent = NewAccountOfferings::CbrainApiAgent
    #uid = agent.create_user( att )

    #if ! agent.cbrain_success
    #  raise "#{agent.error_message}"
    #end

    res = ApprovalResult.new;
    res.plain_password = password
    res.diagnostics    = "Created as UID #{uid}"

    return res
  end

  def account_exists?
    return nil if self.email.blank?
    userlist = []
    userlist << User.find_by_email(self.email)
    userlist << User.find_by_login(self.login)
    #userlist += User.find_by_login(self.login)
    return nil if userlist.blank?
    return userlist[0]
  end

  def undo_approval
    puts "Cancelling: #{self.full}"

    cbrain_user = self.account_exists?
    return false unless cbrain_user

    agent = NewAccountOfferings::CbrainApiAgent
    id    = cbrain_user["id"][0]["content"] rescue nil # darn stupid structure returned by XmlSimple
    return false unless id
    agent.destroy_user(id)
    agent.cbrain_success
  rescue
    false
  end

  def after_failed_user_notification
    undo_approval
  end

  def undo_approval
    puts "Undo approval: #{self.full}"

    loris_user = self.account_exists?
    return false unless loris_user

    loris_user.destroy
    true
  end


end

