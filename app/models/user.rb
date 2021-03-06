class User
  include Mongoid::Document
  include Mongoid::Timestamps::Created # save registration date

  before_save :ensure_authentication_token

  # Include default devise modules. Others available are:
  # :token_authenticatable, :encryptable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, :token_authenticatable, 
         :recoverable, :rememberable, :trackable, :validatable, :omniauthable
         
  ## Database authenticatable
  field :email,              :type => String, :null => false, :default => ""
  field :encrypted_password, :type => String, :null => false, :default => ""

  ## Recoverable
  field :reset_password_token,   :type => String
  field :reset_password_sent_at, :type => Time

  ## Rememberable
  field :remember_created_at, :type => Time

  ## Trackable
  field :sign_in_count,      :type => Integer, :default => 0
  field :current_sign_in_at, :type => Time
  field :last_sign_in_at,    :type => Time
  field :current_sign_in_ip, :type => String
  field :last_sign_in_ip,    :type => String

  ## Confirmable
  # field :confirmation_token,   :type => String
  # field :confirmed_at,         :type => Time
  # field :confirmation_sent_at, :type => Time
  # field :unconfirmed_email,    :type => String # Only if using reconfirmable

  ## Lockable
  # field :failed_attempts, :type => Integer, :default => 0 # Only if lock strategy is :failed_attempts
  # field :unlock_token,    :type => String # Only if unlock strategy is :email or :both
  # field :locked_at,       :type => Time

  ## Token authenticatable
  field :authentication_token, :type => String

  field :name, :type => String
  
  def self.find_for_facebook_oauth(access_token, signed_in_resource=nil)
    data = access_token.extra.raw_info
    if user = User.where(:email => data.email).first
      user
    else # Create a user with a stub password. 
      User.create!(:email => data.email, :password => Devise.friendly_token[0,20], :name => "#{data.first_name} #{data.last_name}") 
    end
  end
  
  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session["devise.facebook_data"] && session["devise.facebook_data"]["extra"]["raw_info"]
        user.email = data["email"]
      end
    end
  end

  def self.find_for_google_oauth2(access_token, signed_in_resource=nil)
    data = access_token.info
    user = User.where(:email => data.email).first

    unless user
        user = User.create(name: data.name,
             email: data.email,
             password: Devise.friendly_token[0,20]
            )
    end
    user
  end
  
  embeds_many :events
  accepts_nested_attributes_for :events
  
  has_many :ads
  
  def add_course!(course)
    dates = course.get_dates(true)
    unless self.has_course?(course)
      dates.each do |date|
        event = self.events.build
        event.start_time = date[0]
        event.end_time = date[1]
        event.name = course.title
        event.description = date[3]
        event.location = date[2]
        event.course = course
        event.save!
      end
    end
  end
  
  def update_non_custom_courses!
    courses = self.events.map(&:course_id).uniq
    courses.each do |c|
      begin
        course = Course.find(c)
        self.events.where(course_id: c).where(custom: false).delete_all
        self.add_course!(course)
      rescue
        self.events.where(course_id: c).where(custom: false).delete_all
      end
    end
  end

  def has_course?(course)
    self.events.any? do |event|
      event.custom == false && event.course_id == course.id
    end
  end

  alias_method :"has_event?", :"has_course?"
  
end
