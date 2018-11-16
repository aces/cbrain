
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

describe PortalTask::ParamsErrors do

  let(:task)   { CbrainTask::SimpleMonitor.new(:params => {}) }
  let(:params) { task.params          }
  let(:errors) { task.params_errors   }

  it "should work on a PortalTask::ParamsErrors object" do
    expect(errors.class).to be(PortalTask::ParamsErrors)
  end

  describe "with method blank?" do

    it "should return true when there are no errors" do
      expect(errors.blank?).to eq(true)
    end

    it "should return false when there is an error" do
      errors.add(:xyz, "yep")
      expect(errors.blank?).to eq(false)
    end

  end

  describe "with method count" do

    it "should return 0 when there are no errors" do
      expect(errors.count).to eq(0)
    end

    it "should return 1 when there is an error" do
      errors.add(:xyz, "yep")
      expect(errors.count).to eq(1)
    end

  end

  describe "with methods [] and []=" do

    it "should assign an error with []= and return it with []" do
      errors[:abc] = "bad"
      expect(errors.count).to eq(1)
      expect(errors[:abc]).to eq( [ "bad" ] )
    end

    it "should store two errors with two []= and []" do
      errors[:abc] = "bad"
      errors[:abc] = "superbad"
      expect(errors.count).to eq(2)
      expect(errors[:abc]).to eq( [ "bad", "superbad" ] )
    end

  end

  describe "with full_messages" do

    it "should generates messages" do
      errors[:abc] = "is bad"
      errors[:abc] = "is rather bad"
      errors[:def] = "is quite good"
      expect(errors.full_messages).to eq( [ "Abc is bad", "Abc is rather bad", "Def is quite good" ] )
    end

  end

  describe "with add_on_blank" do

    describe "at top level of params" do

      it "should record the blankness when the params is blank" do
        params[:myblank] = " "
        errors.add_on_blank(:myblank)
        expect(errors[:myblank]).to eq( [ 'is blank' ] )
      end

      it "should do nothing when the params is present" do
        params[:mypresent] = "Hello"
        errors.add_on_blank(:mypresent)
        expect(errors[:mypresent]).to eq( [ ] )
      end

    end

    describe "at lower levels of params" do

      it "should record the blankness when the params is blank" do
        params[:myhash] = { :myblank => " " }
        errors.add_on_blank("myhash[myblank]")
        expect(errors["myhash[myblank]"]).to eq( [ 'is blank' ] )
      end

      it "should do nothing when the params is present" do
        params[:myhash] = { :mypresent => "Salutations" }
        errors.add_on_blank("myhash[mypresent]")
        expect(errors["myhash[mypresent]"]).to eq( [ ] )
      end

    end

  end

  describe "with add_on_empty" do

    describe "at top level of params" do

      it "should record the emptiness when the params is an empty array" do
        params[:myempty] = []
        errors.add_on_empty(:myempty)
        expect(errors[:myempty]).to eq( [ 'is empty' ] )
      end

      it "should do nothing when the params is present" do
        params[:mypresent] = [ 1, 2, 3 ]
        errors.add_on_empty(:mypresent)
        expect(errors[:mypresent]).to eq( [ ] )
      end

    end

    describe "at lower levels of params" do

      it "should record the emptiness when the params is an empty array" do
        params[:myhash] = { :myempty => [] }
        errors.add_on_empty("myhash[myempty]")
        expect(errors["myhash[myempty]"]).to eq( [ 'is empty' ] )
      end

      it "should do nothing when the params is present" do
        params[:myhash] = { :mypresent => [ 1, 2, 3 ] }
        errors.add_on_empty("myhash[mypresent]")
        expect(errors["myhash[mypresent]"]).to eq( [ ] )
      end

    end

  end

  describe "with keys" do

    it "should return nothing when there are no errors" do
      expect(errors.keys).to eq([])
    end

    it "should return keys when there are errors"  do
      errors.add(:abc, "no good")
      errors.add(:abc, "bad bad")
      errors.add(:def, "oh no no no")
      errors.add("stupid[deep[struct]]", "way bad")
      expect(errors.keys).to eq([ "abc", "def", "stupid[deep[struct]]" ])
    end

  end

  describe "with values" do

    it "should return nothing when there are no errors" do
      expect(errors.values).to eq([])
    end

    it "should return values when there are errors" do
      errors.add(:abc, "no good")
      errors.add(:abc, "bad bad")
      errors.add(:def, "oh no no no")
      errors.add("stupid[deep[struct]]", "way bad")
      expect(errors.values).to eq([ [ "no good", "bad bad" ], [ "oh no no no" ], [ "way bad" ] ])
    end

  end

  describe "with each" do

    it "should not iterate when there are no errors" do
      got_inside = false
      errors.each { |k,v| got_inside = true }
      expect(got_inside).to be(false)
    end

    it "should iterate over the entries" do
      errors.add(:abc, "x")
      errors.add(:abc, "y")
      errors.add(:def, "z")
      errors.add("stupid[deep[struct]]", "w")
      seen={}
      errors.each { |k,v| seen[v] = true }
      expect(seen.keys.sort).to eq( [ "w", "x", "y", "z" ] )
    end

  end

  # NOTE: get() is deprecated

  describe "with delete" do

    it "should remove a key" do
      errors.add(:abc,"a")
      errors.add(:def,"b")
      errors.add(:xyz,"x")
      errors.delete(:def)
      expect(errors.keys.sort).to eq([ "abc", "xyz" ])
    end

  end

  describe "with get" do

    it "should work like [] basically" do
      errors.add(:abc, "bad")
      expect(errors.get(:abc)).to eq(errors[:abc])
    end

  end

  describe "with include" do

    it "should return true or false if the key is there or not" do
      errors.add(:abc, "bad")
      errors.add(:def, "ok")
      expect([ errors.include?(:xyz), errors.include?(:abc), errors.include?(:def) ] ).to eq( [ false, true, true ] )
    end

  end

  describe "with to_hash" do

    it "should generate a nice hash" do
      errors.add(:abc,              "superbad")
      errors.add("deep[struct[0]]", "terrible")
      expect(errors.to_hash).to eq( { "abc" => [ "superbad" ], "deep[struct[0]]" => [ "terrible" ] } )
    end

  end

  describe "with to_xml" do

    it "should generate a XML output" do
      errors.add(:abc,              "superbad")
      errors.add("deep[struct[0]]", "terrible")
      expect(errors.to_xml).to eq( <<XML
<?xml version="1.0" encoding="UTF-8"?>
<errors>
  <error>Abc superbad</error>
  <error>Deep[struct[0]] terrible</error>
</errors>
XML
      )
    end

  end

end
