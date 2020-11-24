# frozen_string_literal: true

module GitHelpers
  def create_branch(
    repository_name: 'repository_name',
    name: 'path/branch',
    last_modified_date: Time.current,
    author_name: 'Author Name',
    author_email: 'author@email.com'
  )
    git_data = Git::TestHelpers.create_branch(
      repository_name: repository_name,
      name: name,
      last_modified_date: last_modified_date,
      author_name: author_name,
      author_email: author_email
    )
    ::Branch.create_from_git_data!(git_data)
  end

  def create_branches(
    repository_name: 'repository_name',
    author_name: 'Author Name',
    author_email: 'author@email.com',
    count: 2
  )
    branches = []
    (0..count - 1).each do |i|
      branches << create_branch(
        repository_name: repository_name,
        name: "path/#{author_name}/branch#{i}",
        last_modified_date: DateTime.current,
        author_name: author_name,
        author_email: author_email
      )
    end
    branches
  end

  def create_commit(
    sha: '1234567890123456789012345678901234567890',
    message: 'Commit message',
    author_name: 'Author Name',
    author_email: 'author@email.com'
  )
    commit = ::Commit.create(sha: sha, message: message)
    commit.author = ::User.first_or_create!(name: author_name, email: author_email)
    commit.save!
    commit
  end

  def create_commits(author_name: 'Author Name', author_email: 'author@email.com', count: 2)
    commits = []
    (0..count - 1).each do |i|
      commits << create_commit(
        sha: (i + 1).to_s.ljust(40, '0'),
        message: "Commit message #{i + 1}",
        author_name: author_name,
        author_email: author_email
      )
    end
    commits
  end
end
