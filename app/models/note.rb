require 'carrierwave/orm/activerecord'
require 'file_size_validator'

class Note < ActiveRecord::Base
  include NoteRepository

  attr_accessible :note, :noteable, :noteable_id, :noteable_type, :project_id,
                  :attachment, :line_code

  attr_accessor :notify
  attr_accessor :notify_author

  belongs_to :project
  belongs_to :noteable, polymorphic: true
  belongs_to :author, class_name: "User"

  delegate :name, to: :project, prefix: true
  delegate :name, :email, to: :author, prefix: true

  validates :project, presence: true
  validates :note, presence: true, length: { within: 0..5000 }
  validates :attachment, file_size: { maximum: 10.megabytes.to_i }

  mount_uploader  :attachment, AttachmentUploader

  class << self
    def create_status_change_note(noteable, author, status)
      create({
        noteable: noteable,
        project: noteable.project,
        author: author,
        note: "_Status changed to #{status}_"
      }, without_protection: true)
    end
  end

  def notify
    @notify ||= false
  end

  def notify_author
    @notify_author ||= false
  end

  def target
    if noteable_type == "Commit"
      project.commit(noteable_id)
    else
      noteable
    end
  # Temp fix to prevent app crash
  # if note commit id doesnt exist
  rescue
    nil
  end

  # Check if we can notify commit author
  # with email about our comment
  #
  # If commit author email exist in project
  # and commit author is not passed user we can
  # send email to him
  #
  # params:
  #   user - current user
  #
  # return:
  #   Boolean
  #
  def notify_only_author?(user)
    commit? && commit_author &&
      commit_author.email != user.email
  end

  def commit?
    noteable_type == "Commit"
  end

  def commit_author
    @commit_author ||=
      project.users.find_by_email(target.author_email) ||
      project.users.find_by_name(target.author_name)
  rescue
    nil
  end

  # Returns true if this is an upvote note,
  # otherwise false is returned
  def upvote?
    note.start_with?('+1') || note.start_with?(':+1:')
  end

  # Returns true if this is a downvote note,
  # otherwise false is returned
  def downvote?
    note.start_with?('-1') || note.start_with?(':-1:')
  end
end

# == Schema Information
#
# Table name: notes
#
#  id            :integer         not null, primary key
#  note          :text
#  noteable_id   :string(255)
#  noteable_type :string(255)
#  author_id     :integer
#  created_at    :datetime        not null
#  updated_at    :datetime        not null
#  project_id    :integer
#  attachment    :string(255)
#  line_code     :string(255)
#
