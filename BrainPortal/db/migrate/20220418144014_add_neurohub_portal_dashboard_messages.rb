class AddNeurohubPortalDashboardMessages < ActiveRecord::Migration[5.0]

  ORIG_MESSAGES = [

    #----------------------------------------------------------------

    [
    'UK Biobank Dataset Access back fully online',
    <<-BODY,
      <p> The Narval cluster of Calcul Québec / Compute Canada is now back online
          The site is now operating under a temporary power configuration until regular
          power delivery can be re-established. As a result, all modes of access to
          the UK Biobank dataset available through NeuroHub are now fully functional and back online.
      </p>
    BODY
    DateTime.parse("2022-03-18 12:00:00"),
    ],

    #----------------------------------------------------------------

    [
    'Compute Canada Narval and Beluga Systems offline affecting UK Biobank Dataset Access',
    <<-BODY,
      <p> The Narval and Beluga systems of Compute Canada are offline since
          March 8, 2022 due to a major issue.  All compute and storage resources
          access is offline.  This includes all access to the UK Biobank and Human
          Connectome Project (HCP) datasets through NeuroHub.  More information will
          be provided as details and timelines emerge from Compute Canada.
      </p>
    BODY
    DateTime.parse("2022-03-08 12:00:00"),
    ],

    #----------------------------------------------------------------


    [
    'Recently added datasets',
    <<-BODY,
      <p>
        <strong>2020-07-13: UK BioBank T1s in MINC (UKBB, request access)</strong><br>
        &rarr; 39,676 MincFiles, 482.1 GB<br>
        <strong>2020-08-28: Visual Working Memory (CONP, public)</strong><br>
        &rarr; 19 BidsSubjects, 209 files, 6.4 GB<br>
        <strong>2020-10-13: Open PreventAD (CONP, request access)</strong><br>
        &rarr; 308 FileCollections, 28,747 files, 237.9 GB<br>
        <strong>2020-10-13: Open PreventAD BIDS (CONP, request access)</strong><br>
        &rarr; 308 BidsSubjects, 53,053 files, 246.0 GB<br>
        <strong>2020-10-22: UK BioBank CIVET outputs (UKBB, request access)</strong><br>
        &rarr; 39,207 CivetOutputs, 9,135,212 files, 26.3 TB<br>
        <strong>2020-11-15: OpenPain (CONP, 6 datasets, public)</strong><br>
        &rarr; 7,203 files, 806 GB<br>
        <br>
        <em>Please do not copy large sections of these datasets</em>;
        if you need help extracting information out of them, contact us,
        we will prepare this for you.
      </p>
    BODY
    DateTime.parse("2020-10-22 12:00:00"),
    ],

    #----------------------------------------------------------------

    [
    'Survey',
    <<-BODY,
       <p>
         Dear Users, to help us improve the platform and your user experience,
         please fill out the survey:<br><br>
         <a target="_blank" class="btn-solid cbrain" href="https://docs.google.com/forms/d/e/1FAIpQLSfQnYwSUgzj6VMXEUMFEpsFZC0A9lwJVSc-Vbvpy3drjmebkQ/viewform">survey</a>
       </p>
    BODY
    DateTime.parse("2020-05-21 12:00:00"),
    ],

  ]

  def up
    puts "Creating Neurohub Dashboard messages:\n"
    ORIG_MESSAGES.each do |triplet|
      header, body, time = *triplet
      puts " -> #{header}"
      Message.create!(
        :message_type => 'neurohub_dashboard',
        :header       => header,
        :description  => body,
        :created_at   => time,
        :user_id      => User.admin.id,
        :expiry       => nil,
        :last_sent    => time,
        :critical     => false,
        :display      => true,
      )
    end
  end

  def down
    puts "Removing Neurohub Dashboard messages:\n"
    ORIG_MESSAGES.each do |triplet|
      header, body, _ = *triplet
      puts " -> #{header}"
      Message.where(:header => header, :description => body).first.try(:destroy)
    end
  end

end
