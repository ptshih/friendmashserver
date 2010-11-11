# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Facemash::Application.initialize!

config.action_controller.logger = Logger.new(STDOUT)
