
# CPU Quota test suite

# Do not run this in production!
# THIS WILL DELETE ALL CPUQUOTA OBJECTS
# IN THE DB WHILE IT RUNS!

1.times do # just a block for the whole thing

if Rails.env != 'development'
  puts "ERROR Eh, only run this in a dev environement!"
  puts <<-WARN
    THIS WILL DELETE ALL CPUQUOTA OBJECTS
    IN THE DB WHILE IT RUNS!
  WARN
  break # stop everything
end

user     = NormalUser.first
bourreau = Bourreau.first
group    = WorkGroup.find_or_create_by(
  :name       => 'quotaed users',
  :creator_id => 1,
)
group.user_ids |= [ 1, user.id ]

  # Non-zero: user_id, bourreau_id             # Note: group_id is ignored
  # Non-zero: user_id                          # Note: group_id is ignored
  # Non-zero:          bourreau_id, group_id
  # Non-zero:          bourreau_id
  # Non-zero:                       group_id

# The order of these quotas match the final 5 columns of usage_test
quotas = [
  #  u, b, g,   week, month, ever
  [  1, 1, 0,    5,   10,   20 ],
  [  1, 0, 0,   10,   20,   40 ],
  [  0, 1, 1,   15,   30,   60 ],
  [  0, 1, 0,   20,   40,   80 ],
  [  0, 0, 1,   25,   50,  100 ],
]

usage_test = [
  # week month ever result for each of the five quotas
  # ---- ----- ---- ---------------------------------
  [   0,   0,   0, ] + %i(   nil   nil   nil   nil   nil ),
  [   1,   1,   1, ] + %i(   nil   nil   nil   nil   nil ),

  [   1,   0,   0, ] + %i(   nil   nil   nil   nil   nil ),
  [   6,   0,   0, ] + %i(  week   nil   nil   nil   nil ),
  [  11,   0,   0, ] + %i(  week  week   nil   nil   nil ),
  [  16,   0,   0, ] + %i(  week  week  week   nil   nil ),
  [  21,   0,   0, ] + %i(  week  week  week  week   nil ),
  [  26,   0,   0, ] + %i(  week  week  week  week  week ),

  [   0,   1,   0, ] + %i(   nil   nil   nil   nil   nil ),
  [   0,  11,   0, ] + %i( month   nil   nil   nil   nil ),
  [   0,  21,   0, ] + %i( month month   nil   nil   nil ),
  [   0,  31,   0, ] + %i( month month month   nil   nil ),
  [   0,  41,   0, ] + %i( month month month month   nil ),
  [   0,  51,   0, ] + %i( month month month month month ),

  [   0,   0,   1, ] + %i(   nil   nil   nil   nil   nil ),
  [   0,   0,  21, ] + %i(  ever   nil   nil   nil   nil ),
  [   0,   0,  41, ] + %i(  ever  ever   nil   nil   nil ),
  [   0,   0,  61, ] + %i(  ever  ever  ever   nil   nil ),
  [   0,   0,  81, ] + %i(  ever  ever  ever  ever   nil ),
  [   0,   0, 101, ] + %i(  ever  ever  ever  ever  ever ),

#  [  1, 1, 0,    5,   10,   20 ],
#  [  1, 0, 0,   10,   20,   40 ],
#  [  0, 1, 1,   15,   30,   60 ],
#  [  0, 1, 0,   20,   40,   80 ],
#  [  0, 0, 1,   25,   50,  100 ],

  [   4,   4,   4, ] + %i(   nil   nil   nil   nil   nil ),
  [   8,   8,   8, ] + %i(  week   nil   nil   nil   nil ),
  [  12,  12,  12, ] + %i(  week  week   nil   nil   nil ),
  [  16,  16,  16, ] + %i(  week  week  week   nil   nil ),
  [  24,  24,  24, ] + %i(  week  week  week  week   nil ),
  [  30,  30,  30, ] + %i(  week  week  week  week  week ),

  [   4,   8,   0, ] + %i( month   nil   nil   nil   nil ),
  [   4,  18,   0, ] + %i( month month   nil   nil   nil ),
  [   4,  28,   0, ] + %i( month month month   nil   nil ),
  [   4,  38,   0, ] + %i( month month month month   nil ),
  [   4,  48,   0, ] + %i( month month month month month ),

  [   2,   0,  19, ] + %i(  ever   nil   nil   nil   nil ),
  [   2,   0,  39, ] + %i(  ever  ever   nil   nil   nil ),
  [   2,   0,  59, ] + %i(  ever  ever  ever   nil   nil ),
  [   2,   0,  79, ] + %i(  ever  ever  ever  ever   nil ),
  [   2,   0,  99, ] + %i(  ever  ever  ever  ever  ever ),

  [   0,   2,  19, ] + %i(  ever   nil   nil   nil   nil ),
  [   0,   2,  39, ] + %i(  ever  ever   nil   nil   nil ),
  [   0,   2,  59, ] + %i(  ever  ever  ever   nil   nil ),
  [   0,   2,  79, ] + %i(  ever  ever  ever  ever   nil ),
  [   0,   2,  99, ] + %i(  ever  ever  ever  ever  ever ),

  [   2,   2,  17, ] + %i(  ever   nil   nil   nil   nil ),
  [   2,   2,  37, ] + %i(  ever  ever   nil   nil   nil ),
  [   2,   2,  57, ] + %i(  ever  ever  ever   nil   nil ),
  [   2,   2,  77, ] + %i(  ever  ever  ever  ever   nil ),
  [   2,   2,  97, ] + %i(  ever  ever  ever  ever  ever ),

]

uweek_ar = CputimeResourceUsageForCbrainTask.where(
  :user_id            => user.id,
  :cbrain_task_type   => 'FakeWeeklyUsage',
  :remote_resource_id => bourreau.id,
)
uweek = uweek_ar.first || uweek_ar.where(:value => 0).create!

umonth_ar = CputimeResourceUsageForCbrainTask.where(
  :user_id            => user.id,
  :cbrain_task_type   => 'FakeMonthlyUsage',
  :remote_resource_id => bourreau.id,
)
umonth = umonth_ar.first || umonth_ar.where(:value => 0).create!

uever_ar = CputimeResourceUsageForCbrainTask.where(
  :user_id            => user.id,
  :cbrain_task_type   => 'FakeTotalUsage',
  :remote_resource_id => bourreau.id,
)
uever = uever_ar.first || uever_ar.where(:value => 0).create!

uweek.update_column( :created_at, 2.days.ago)
umonth.update_column(:created_at, 2.weeks.ago)
uever.update_column( :created_at, 2.months.ago)


#quotas.each do |u,b,g,week,month,ever|
# CpuQuota.find_or_create_by!(
#   :user_id            => u * user.id,
#   :remote_resource_id => b * bourreau.id,
#   :group_id           => g * group.id,
#   :max_cpu_past_week  => week,
#   :max_cpu_past_month => month,
#   :max_cpu_ever       => ever,
# )
#end

stopall=nil
usage_test.each do |testarray|
  puts "Checking: #{testarray.inspect}"
  week,month,ever,*results = *testarray

  # Sets up what the user has been up to
  uweek .update_column(:value, week)
  umonth.update_column(:value, month)
  uever .update_column(:value, ever)

  # Create and test each quota object
  quotas.each_with_index do |quotaspec,idx|

    expected = results[idx]
    expected = nil if expected == :nil # symbol -> nil

    u,b,g,qweek,qmonth,qever = *quotaspec
    CpuQuota.delete_all
    quota = CpuQuota.create!(
      :user_id            => u * user.id,
      :remote_resource_id => b * bourreau.id,
      :group_id           => g * group.id,
      :max_cpu_past_week  => qweek,
      :max_cpu_past_month => qmonth,
      :max_cpu_ever       => qever,
    )

    check = quota.exceeded?(user.id, bourreau.id)

    if check != expected
      puts "Test Failure: check=#{check} expect=#{expected}"
      puts "Usage: #{week}, #{month}, #{ever}"
      puts "Quota: #{qweek}, #{qmonth}, #{qever} U=#{u} B=#{b} G=#{g}"
      stopall=true
    end

    break if stopall
  end # each quota

  break if stopall
end # each test

end # 1.times
