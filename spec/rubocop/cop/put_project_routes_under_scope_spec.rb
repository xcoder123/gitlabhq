# frozen_string_literal: true

require 'fast_spec_helper'
require 'rubocop'
require_relative '../../../rubocop/cop/put_project_routes_under_scope'

describe RuboCop::Cop::PutProjectRoutesUnderScope, type: :rubocop do
  include CopHelper

  subject(:cop) { described_class.new }

  before do
    allow(cop).to receive(:in_project_routes?).and_return(true)
  end

  it 'registers an offense when route is outside scope' do
    expect_offense(<<~PATTERN)
      scope '-' do
        resource :issues
      end

      resource :notes
      ^^^^^^^^^^^^^^^ Put new project routes under /-/ scope
    PATTERN
  end

  it 'does not register an offense when resource inside the scope' do
    expect_no_offenses(<<~PATTERN)
      scope '-' do
        resource :issues
        resource :notes
      end
    PATTERN
  end

  it 'does not register an offense when resource is deep inside the scope' do
    expect_no_offenses(<<~PATTERN)
      scope '-' do
        resource :issues
        resource :projects do
          resource :issues do
            resource :notes
          end
        end
      end
    PATTERN
  end
end
