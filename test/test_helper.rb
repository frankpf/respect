require 'test/unit'

require 'respect'
require 'respect/unit_test_helper'

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

# A module to test statement extension helper.
module EndUserDSLStatement

  def id(name = "id")
    integer name, greater_than: 0
  end

  def call_to_kernel
    # The point is to call an instance method of the Kernel module.
    integer "kernel", equal_to: Integer(0)
  end

  def call_to_object
    # The point is to call an instance method of the Object class.
    string "object", equal_to: self.class.to_s
  end

end

Respect.extend_dsl_with(EndUserDSLStatement)

FORMAT_HELPER_STATEMENTS_LIST = [
  :phone_number,
  :hostname,
  :email,
]

PRIMITIVE_STATEMENTS_LIST = [
  :integer,
  :string,
  :any,
  :boolean,
  :null,
  :float,
  :numeric,
  :uri,
  :regexp,
  :datetime,
  :ipv4_addr,
  :ipv6_addr,
  :ip_addr,
]

TERMINAL_STATEMENTS_LIST = FORMAT_HELPER_STATEMENTS_LIST + PRIMITIVE_STATEMENTS_LIST

COMPOSITE_STATEMENTS_LIST = [
  :object,
  :array,
]

BASIC_STATEMENTS_LIST = TERMINAL_STATEMENTS_LIST + COMPOSITE_STATEMENTS_LIST

require "mocha/setup"
