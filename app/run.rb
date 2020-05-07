require 'tty-prompt'
ActiveRecord::Base.establish_connection(
    :adapter => "sqlite3",
    :database => "db/donations.db")  
class StayWokeCLI
    attr_accessor :user, :temp_user, :temp_active
    attr_reader :heart
    def initialize
        @prompt = TTY::Prompt.new
        @heart = @prompt.decorate(@prompt.symbols[:heart] + ' ', :bright_magenta)
        @temp_active = false
    end
    def welcome
      resp = @prompt.yes?('Welcome to Stay Woke! Is it your first time waking up?')
      resp || User.first.nil? ? new_user : find_user_name  #pretty genius || to stop login attempt to an empty db :)
      login
    end
    def new_user
        args = {}
        args[:first_name] = @prompt.ask("We've been expecting you. It's never too late to wake up and find out what's going on. Staying woke takes daily practice and mindfulness.  Let's help you with that by setting up a user profile. If I need to ask you a question, what is your first name?")
        args[:last_name] = @prompt.ask("Thanks, #{args[:first_name]}.  We won't share your information to any third-party vendors (until we get Series A Funding, at least).  Is there a family name you'd like to use?")
        args[:address] = @prompt.ask("In order to properly assist you #{args[:first_name]}, your address will be required. This information will be kept completely private unless you try to break our code.")
        seed_initial_data(args)
        puts "Let's fucking do this! You'll need a password to access the system."
    end
    def find_user_name #displays users in database  and user can select one to attempt to log in with
       names = User.all.map do |n|
            "#{n[:first_name]} #{n[:last_name]}"
        end
        resp = @prompt.select("Select a user:", names)
        first, last = resp.split
        @user = User.find_by(first_name: first, last_name: last)# could use new variable of name = first + last
        # choices = []
        # User.all.each do |n|
        #     choices << "#{n[:first_name]} #{n[:last_name]}"
        #     choices << n.id
        # end
        # @user = @prompt.select("Select a user:", Hash[choices]) 
    end
    def login
        #checks the newly loaded @user variable for a password.  if new user, create and exit w/ true.  if password, ask for password and rturn
        if @user.password.nil?
            resp = @prompt.mask("Please create a password:", mask: @heart)
            @user.update(password: resp)
            return true
        else 
             3.times do 
                resp = @prompt.mask("Please enter your password:", mask: @heart)
                return true if resp == @user.password
             end
             welcome #this is where they failed to login  
         end
        #check and branch to new_user or set instance variables
    end
    def main_menu
        @temp_user.destroy if @temp_user
        @temp_active = false #reset temp_user when returning to main menu
        @temp_user = nil
        choices = {"Show Information for My District" => 2,
             "Show Information for Another District" => 3,
             "Settings" => 4, "Exit" => 1
            }
       resp = @prompt.select("Please choose from one of the following:", choices, cycle: true)
       case resp
        when 1
            exit
        when 2
            info_for_district(@user)
        when 3
            info_for_district(retrieve_other_address_as_user_obj)
        when 4
            settings
       end
    end
    def exit
        puts "Enjoy your slumber. Come back when you're ready to be woke."  #colorify this shit Tisdale!
    end
    def retrieve_other_address_as_user_obj  #give user a chance to enter a new address to see data for; give option for random address with 'random'
        other_address = @prompt.ask("Enter a US address or 'random' to retrieve district info:", default: "1520 Marion Lincoln Park MI")
        @temp_active = true
        seed_initial_data(address: other_address)
        @temp_user
    end
    def info_for_district(user)
       choices = {user.politicians[0].name => 1, user.politicians[1].name => 2, user.politicians[2].name => 3, "Return to Main Menu" => 4}
       resp = @prompt.select("Please choose one of the following:", choices, cycle: true)
       case resp
       when 1
           show_politician_info(user.politicians[0])
       when 2
           show_politician_info(user.politicians[1])
       when 3
           show_politician_info(user.politicians[2])
       when 4
        main_menu
       end
    end
    def show_politician_info(pol)   #
        choices = {pol.domain=>1, pol.title=>2, "@" + pol.twitter=>3, "Return to District"=>4}
        resp = @prompt.select("Showing Info for #{pol.name}", choices)
        case resp
        when 4
            result = @temp_active ? @temp_user : @user
            info_for_district(result)
        end
    end
    def settings
        choices = {"Delete Data" => 1,
            "Delete Account" => 2,
            "Change Address" => 3,
            "Change Password" => 4,
            "Return to Main Menu" => 5
        }
        resp = @prompt.select("Please choose from one of the following:", choices, cycle: true)
            case resp
            when 1
                delete_data
            when 2
                delete_account
            when 3
                change_address
            when 4 
                change_password
            when 5
                main_menu
            end
    end
    def delete_data
    end
    def delete_account
        @user.destroy
        puts "Account deleted. Don't feed the hand that bites you." 
        welcome
    end
    def change_address
        args = @user.attributes
        args[:address] = @prompt.ask("Current Address: #{@user.address}   New Address?")
        @user.destroy
        @user = seed_initial_data(args)
        settings
    end
    def change_password
        @user.password = @prompt.ask("Current Password: #{@user.password}   New Password?")
        @user.save
        settings
    end
    def exit
       puts "Enjoy your slumber. Come back when you're ready to be woke."
    end
    private
    def seed_initial_data(args)
        puts "Building your initial dataset...."   #COLORIFY TISDALE
        hold_me = User.create(args)
        hold_me.find_my_servants
        puts "Retrieving info about: " + hold_me.politicians.pluck(:name).join("    ")
        hold_me.politicians.pluck(:candidate_id).each {|can| GetCandidateInfo.new(can).seek if Politician.find_by(candidate_id: can).committees.empty?}
        hold_me.politicians.each do |pol|
            pol.committees.each {|com| GetCommitteeReceipts.new(com, true).seek} 
        end
        @temp_active ? @temp_user = hold_me : @user = hold_me
    end
end
# #run.rb will start here  (maybe some require_relative statements idfk but just the below codes)
sess = StayWokeCLI.new
puts sess.welcome
sess.main_menu