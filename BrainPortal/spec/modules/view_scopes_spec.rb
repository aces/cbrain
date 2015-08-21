
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

require 'rails_helper'

describe ViewScopes do
  # TODO
end

module ViewScopes
  describe Scope do
    # TODO
  end

  describe Scope::Filter do
    let(:filter) { Scope::Filter.from_hash({ :attribute => :full_name, :value => 'A' }) }

    wacky_string = lambda do
      (1..0x1000)
        .to_a
        .shuffle
        .map { |v| v.chr.encode('utf-8') rescue nil }
        .compact
        .join
    end

    it "should be created blank" do
      blank = Scope::Filter.new
      [ :attribute, :value, :operator, :association ].each do |attr|
        expect(blank.send(attr)).to be_nil
      end
    end

    it "should have no type name" do
      expect(Scope::Filter.type_name).to be_nil
    end

    it "shouldn't be valid if blank" do
      expect(Scope::Filter.new.valid?).to be_falsey
    end

    context "when filtering a model" do
      let!(:a) { create(:normal_user, :full_name => 'A') }
      let!(:b) { create(:normal_user, :full_name => 'B') }
      let!(:c) { create(:normal_user, :full_name => 'B') }
      let!(:d) { create(:normal_user, :full_name => 'C') }

      before do
        @expect_each = lambda do |op, tests|
          filter.operator = op
          tests.map do |value, expected|
            filter.value = value
            expect(filter.apply(NormalUser).to_a).to match_array(expected)
          end
        end
      end

      it "should throw an exception if the filter has no operator" do
        filter.operator = nil
        expect { filter.apply(NormalUser) }.to raise_error
      end

      it "should throw an exception if the filter has no attribute" do
        filter.attribute = nil
        expect { filter.apply(NormalUser) }.to raise_error
      end

      it "should validate the attribute name" do
        filter.attribute = wacky_string.()
        expect { filter.apply(NormalUser) }.to raise_error(RuntimeError, /(attribute|column|table)/)
      end

      it "should support standard operators" do
        filter.value = b.full_name

        ({
          :== => [b, c],
          :!= => [a, d],
          :>  => [d],
          :>= => [b, c, d],
          :<  => [a],
          :<= => [a, b, c]
        }).each do |op, result|
          filter.operator = op
          expect(filter.apply(NormalUser).to_a).to match_array(result)
        end
      end

      it "should support set inclusion/exclusion" do
        @expect_each.(:in, {
          []              => [],
          ['A']           => [a],
          ['A', 'B', 'K'] => [a, b, c],
          ['K', 'L', 'M'] => [],
        })

        @expect_each.(:out, {
          []              => [a, b, c, d],
          ['A']           => [b, c, d],
          ['A', 'B', 'K'] => [d],
          ['K', 'L', 'M'] => [a, b, c, d],
        })
      end

      it "should support string matching" do
        @expect_each.(:match, {
          'a' => [a],
          'k' => [],
          wacky_string.() => []
        })
      end

      it "should support range matching" do
        @expect_each.(:range, {
          ['A', 'B'] => [a, b, c],
          ['B', 'C'] => [b, c, d],
          ['C', 'A'] => [a, b, c, d],
          ['C', 'K'] => [d],
          ['K', 'Z'] => []
        })
      end

      context "when using an association" do
        it "should support associations"
        it "should allow filtering on association attributes"
        it "should allow join columns"
        it "should validate join columns"
      end

      it "should handle nil values" do
        filter.value     = nil
        filter.attribute = :id

        filter.operator  = :==
        expect(filter.apply(NormalUser).to_a).to match_array([])

        filter.operator  = :!=
        expect(filter.apply(NormalUser).to_a).to match_array([a, b, c, d])
      end
    end

    context "when filtering a collection" do
      let!(:a) { create(:normal_user, :full_name => 'A') }
      let!(:b) { create(:normal_user, :full_name => 'B') }
      let!(:c) { create(:normal_user, :full_name => 'B') }
      let!(:d) { create(:normal_user, :full_name => 'C') }
      let!(:collection) { [a, b, c, d] }

      before do
        @expect_each = lambda do |op, tests|
          filter.operator = op
          tests.map do |value, expected|
            filter.value = value
            expect(filter.apply(collection)).to match_array(expected)
          end
        end
      end

      it "should throw an exception if the filter has no operator" do
        filter.operator = nil
        expect { filter.apply(collection) }.to raise_error
      end

      it "should throw an exception if the filter has no attribute" do
        filter.attribute = nil
        expect { filter.apply(collection) }.to raise_error
      end

      it "should support hash collections (list of hashes)" do
        hashes = collection.map { |i| { :full_name => i.full_name } }
        expect(filter.apply(hashes)).to match_array([{ :full_name => 'A' }])
      end

      it "should support array collections (list of arrays)" do
        filter.attribute = 0
        arrays = collection.map { |i| [i.full_name] }
        expect(filter.apply(arrays)).to match_array([[ 'A' ]])
      end

      it "should convert mismatched value types" do
        filter.value = :A
        expect(filter.apply(collection)).to match_array([a])
      end

      it "should support standard operators" do
        filter.value = b.full_name

        ({
          :== => [b, c],
          :!= => [a, d],
          :>  => [d],
          :>= => [b, c, d],
          :<  => [a],
          :<= => [a, b, c]
        }).each do |op, result|
          filter.operator = op
          expect(filter.apply(collection).to_a).to match_array(result)
        end
      end

      it "should support set inclusion/exclusion" do
        @expect_each.(:in, {
          []              => [],
          ['A']           => [a],
          ['A', 'B', 'K'] => [a, b, c],
          ['K', 'L', 'M'] => [],
        })

        @expect_each.(:out, {
          []              => [a, b, c, d],
          ['A']           => [b, c, d],
          ['A', 'B', 'K'] => [d],
          ['K', 'L', 'M'] => [a, b, c, d],
        })
      end

      it "should support string matching" do
        @expect_each.(:match, {
          'a' => [a],
          'k' => [],
          wacky_string.() => []
        })
      end

      it "should support range matching" do
        @expect_each.(:range, {
          ['A', 'B'] => [a, b, c],
          ['B', 'C'] => [b, c, d],
          ['C', 'A'] => [a, b, c, d],
          ['C', 'K'] => [d],
          ['K', 'Z'] => []
        })
      end
    end

    context "when creating from a hash" do
      it "should be blank from a blank hash" do
        blank = Scope::Filter.from_hash({})
        [ :attribute, :value, :association ].each do |attr|
          expect(blank.send(attr)).to be_nil
        end
      end

      it "should accept attribute hash keys" do
        filter = Scope::Filter.from_hash({
          :attribute   => 'a',
          :value       => 'v',
          :operator    => 'm',
        })

        expect(filter.attribute).to eq('a')
        expect(filter.value).to     eq('v')
        expect(filter.operator).to  eq('match')
      end

      it "should accept short attribute hash keys" do
        filter = Scope::Filter.from_hash({
          :a => 'a',
          :v => 'v',
          :o => 'match',
        })

        expect(filter.attribute).to eq('a')
        expect(filter.value).to     eq('v')
        expect(filter.operator).to  eq('match')
      end

      it "should delegate to a subclass if :type is given" do
        subclass = Class.new(Scope::Filter) do
          def self.type_name
            'test'
          end
        end

        expect((Scope::Filter.from_hash({
          :type => 'test'
        })).class).to eq(subclass)
      end

      it "should validate :operator against the supported operators" do
        expect((Scope::Filter.from_hash({
          :attribute   => 'a',
          :value       => 'v',
          :operator    => 'z',
          :association => 'NormalUser'
        })).operator).to be_nil
      end

      it "should allow short operators" do
        Scope::Filter.from_hash({
          :a => 'a',
          :v => 'v',
          :o => 'match',
          :j => 'NormalUser'
        })
      end

      it "should make :value match the operator" do
        expect((Scope::Filter.from_hash({
          :attribute => 'a',
          :value     => 'v',
          :operator  => 'in',
        })).value).to eq(['v'])

        expect(Scope::Filter.from_hash({
          :attribute => 'a',
          :value     => 'v',
          :operator  => 'range',
        }).value).to be_nil

        expect((Scope::Filter.from_hash({
          :attribute => 'a',
          :value     => ['v'],
          :operator  => '==',
        })).value).to eq('v')
      end

      it "should resolve :association if provided" do
        expect((Scope::Filter.from_hash({
          :attribute   => 'a',
          :value       => ['v'],
          :operator    => '==',
          :association => 'NormalUser'
        })).association).to eq(NormalUser)

        expect((Scope::Filter.from_hash({
          :attribute   => 'a',
          :value       => ['v'],
          :operator    => '==',
          :association => 'users'
        })).association).to eq(User)

        expect((Scope::Filter.from_hash({
          :attribute   => 'a',
          :value       => ['v'],
          :operator    => '==',
          :association => ['users', 'id', 'user_id']
        })).association).to eq([User, 'id', 'user_id'])
      end
    end

    context "when converting to hash" do
      it "should export all attributes" do
        expect(filter.to_hash).to eq({
          'attribute'   => 'full_name',
          'value'       => 'A',
          'operator'    => '==',
          'association' => nil
        })
      end

      context "in compact mode" do
        it "should export only set attributes" do
          expect(filter.to_hash(compact: true)).to eq({
            'a' => 'full_name',
            'v' => 'A'
          })
        end

        it "should shrink attribute keys" do
          expect(filter.to_hash(compact: true)).to eq({
            'a' => 'full_name',
            'v' => 'A'
          })
        end

        it "should shrink long operators" do
          filter.operator = :match
          expect(filter.to_hash(compact: true)).to eq({
            'a' => 'full_name',
            'v' => 'A',
            'o' => 'm'
          })
        end

        it "should remove default values" do
          expect(filter.to_hash(compact: true)).to eq({
            'a' => 'full_name',
            'v' => 'A'
          })
        end
      end
    end
  end

  describe Scope::Order do
    let(:order) { Scope::Order.from_hash({ :attribute => :full_name }) }

    wacky_string = lambda do
      (1..0x1000)
        .to_a
        .shuffle
        .map { |v| v.chr.encode('utf-8') rescue nil }
        .compact
        .join
    end

    it "should be created blank" do
      blank = Scope::Order.new
      [ :attribute, :direction, :association ].each do |attr|
        expect(blank.send(attr)).to be_nil
      end
    end

    it "should have no type name" do
      expect(Scope::Order.type_name).to be_nil
    end

    it "shouldn't be valid if blank" do
      expect(Scope::Order.new.valid?).to be_falsey
    end

    context "when ordering a model" do
      let!(:a) { create(:normal_user, :full_name => 'A') }
      let!(:b) { create(:normal_user, :full_name => 'C') }
      let!(:c) { create(:normal_user, :full_name => 'B') }
      let!(:d) { create(:normal_user, :full_name => 'D') }

      it "should throw an exception if the ordering rule has no direction" do
        order.direction = nil
        expect { order.apply(NormalUser) }.to raise_error
      end

      it "should throw an exception if the ordering rule has no attribute" do
        order.attribute = nil
        expect { order.apply(NormalUser) }.to raise_error
      end

      it "should validate the attribute name" do
        order.attribute = wacky_string.()
        expect { order.apply(NormalUser) }.to raise_error(RuntimeError, /(attribute|column|table)/)
      end

      it "should support sorting/ordering in ascending order" do
        order.direction = :asc
        expect(order.apply(NormalUser)).to eq([a, c, b, d])
      end

      it "should support sorting/ordering in descending order" do
        order.direction = :desc
        expect(order.apply(NormalUser)).to eq([d, b, c, a])
      end

      context "when using an association" do
        it "should support associations"
        it "should allow filtering on association attributes"
        it "should allow join columns"
        it "should validate join columns"
      end
    end

    context "when ordering a collection" do
      let!(:a) { create(:normal_user, :full_name => 'A') }
      let!(:b) { create(:normal_user, :full_name => 'C') }
      let!(:c) { create(:normal_user, :full_name => 'B') }
      let!(:d) { create(:normal_user, :full_name => 'D') }
      let!(:collection) { [a, b, c, d] }

      it "should throw an exception if the ordering rule has no direction" do
        order.direction = nil
        expect { order.apply(collection) }.to raise_error
      end

      it "should throw an exception if the ordering rule has no attribute" do
        order.attribute = nil
        expect { order.apply(collection) }.to raise_error
      end

      it "should support hash collections (list of hashes)" do
        hashes = collection.map { |i| { :full_name => i.full_name } }
        expect(order.apply(hashes)).to eq([
          { :full_name => 'A' },
          { :full_name => 'B' },
          { :full_name => 'C' },
          { :full_name => 'D' }
        ])
      end

      it "should support array collections (list of arrays)" do
        order.attribute = 0
        arrays = collection.map { |i| [i.full_name] }
        expect(order.apply(arrays)).to eq([
          [ 'A' ],
          [ 'B' ],
          [ 'C' ],
          [ 'D' ]
        ])
      end

      it "should support sorting/ordering in ascending order" do
        order.direction = :asc
        expect(order.apply(collection)).to eq([a, c, b, d])
      end

      it "should support sorting/ordering in descending order" do
        order.direction = :desc
        expect(order.apply(collection)).to eq([d, b, c, a])
      end
    end

    context "when creating from a hash" do
      it "should be blank from a blank hash" do
        blank = Scope::Order.from_hash({})
        [ :attribute, :association ].each do |attr|
          expect(blank.send(attr)).to be_nil
        end
      end

      it "should accept attribute hash keys" do
        order = Scope::Order.from_hash({
          :attribute => 'a',
          :direction => 'asc'
        })

        expect(order.attribute).to eq('a')
        expect(order.direction).to eq('asc')
      end

      it "should accept short attribute hash keys" do
        order = Scope::Order.from_hash({
          :a => 'a',
          :d => 'asc'
        })

        expect(order.attribute).to eq('a')
        expect(order.direction).to eq('asc')
      end

      it "should delegate to a subclass if :type is given" do
        subclass = Class.new(Scope::Order) do
          def self.type_name
            'test'
          end
        end

        expect((Scope::Order.from_hash({
          :type => 'test'
        })).class).to eq(subclass)
      end

      it "should only accept :asc and :desc as directions" do
        expect((Scope::Order.from_hash({
          :attribute   => 'a',
          :direction   => 'z',
          :association => 'NormalUser'
        })).direction).to be_nil
      end

      it "should resolve :association if provided" do
        expect((Scope::Order.from_hash({
          :attribute   => 'a',
          :association => 'NormalUser'
        })).association).to eq(NormalUser)

        expect((Scope::Order.from_hash({
          :attribute   => 'a',
          :association => 'users'
        })).association).to eq(User)

        expect((Scope::Order.from_hash({
          :attribute   => 'a',
          :association => ['users', 'id', 'user_id']
        })).association).to eq([User, 'id', 'user_id'])
      end
    end

    context "when converting to hash" do
      it "should export all attributes" do
        expect(order.to_hash).to eq({
          'attribute'   => 'full_name',
          'direction'   => 'asc',
          'association' => nil
        })
      end

      context "in compact mode" do
        it "should export only set attributes" do
          expect(order.to_hash(compact: true)).to eq({
            'a' => 'full_name'
          })
        end

        it "should shrink attribute keys" do
          expect(order.to_hash(compact: true)).to eq({
            'a' => 'full_name'
          })
        end

        it "should remove default values" do
          expect(order.to_hash(compact: true)).to eq({
            'a' => 'full_name'
          })
        end
      end
    end
  end

  describe Scope::Pagination do
    # TODO
  end

  # TODO ...
end
