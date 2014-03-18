class @Annotation extends Annotation
  @Meta
    name: 'Annotation'
    replaceParent: true

  # A set of fields which are public and can be published to the client
  @PUBLIC_FIELDS: ->
    fields: {} # All

Annotation.Meta.collection.allow
  insert: (userId, doc) ->
    # TODO: Check whether inserted document conforms to schema
    # TODO: Check that author really has access to the publication

    return false unless userId

    personId = Meteor.personId userId

    # Only allow insertion if declared author is current user
    personId and doc.author._id is personId

  update: (userId, doc) ->
    return false unless userId

    personId = Meteor.personId userId

    # Only allow update if declared author is current user
    personId and doc.author._id is personId

  remove: (userId, doc) ->
    return false unless userId

    personId = Meteor.personId userId

    # Only allow removal if author is current user
    personId and doc.author._id is personId

# Misuse insert validation to add additional fields on the server before insertion
Annotation.Meta.collection.deny
  # We have to disable transformation so that we have
  # access to the document object which will be inserted
  transform: null

  insert: (userId, doc) ->
    doc.createdAt = moment.utc().toDate()
    doc.updatedAt = doc.createdAt
    doc.highlights = [] if not doc.highlights

    # We return false as we are not
    # checking anything, just adding fields
    false

  update: (userId, doc) ->
    doc.updatedAt = moment.utc().toDate()

    # We return false as we are not
    # checking anything, just updating fields
    false

# TODO: Deduplicate, almost same code is in publication.coffee (in general access control should be something consistent), it is similar also to member adding to a group code
Meteor.methods
  # TODO: Move this code to the client side so that we do not have to duplicate document checks from Annotation.Meta.collection.allow and modifications from Annotation.Meta.collection.deny, see https://github.com/meteor/meteor/issues/1921
  'annotation-grant-read-to-user': (annotationId, userId) ->
    check annotationId, String
    check userId, String

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # We do not check here if annotation exists or if user has already read permission because we have query below with these conditions

    # TODO: Check that userId has an user associated with it? Or should we allow adding persons even if they are not users? So that you can grant permissions to authors, without having for all of them to be registered?

    # TODO: Should be allowed also if user is admin
    # TODO: Should check if userId is a valid one?

    Annotation.documents.update
      _id: annotationId
      $and: [
        $or: [
          'readUsers._id': Meteor.personId()
        ,
          'readGroups._id':
            $in: _.pluck Meteor.person().inGroups, '_id'
        ]
      ,
        'readUsers._id':
          $ne: userId
      ]
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        readUsers:
          _id: userId

  # TODO: Move this code to the client side so that we do not have to duplicate document checks from Publication.Meta.collection.allow and modifications from Publication.Meta.collection.deny, see https://github.com/meteor/meteor/issues/1921
  'annotation-grant-read-to-group': (annotationId, groupId) ->
    check annotationId, String
    check groupId, String

    throw new Meteor.Error 401, "User not signed in." unless Meteor.personId()

    # We do not check here if publication exists or if group has already read permission because we have query below with these conditions

    # TODO: Should be allowed also if user is admin
    # TODO: Should check if groupId is a valid one?

    Annotation.documents.update
      _id: annotationId
      $and: [
        $or: [
          'readUsers._id': Meteor.personId()
        ,
          'readGroups._id':
            $in: _.pluck Meteor.person().inGroups, '_id'
        ]
      ,
        'readGroups._id':
          $ne: groupId
      ]
    ,
      $set:
        updatedAt: moment.utc().toDate()
      $addToSet:
        readGroups:
          _id: groupId

Meteor.publish 'annotations-by-id', (id) ->
  check id, String

  return unless id

  Annotation.documents.find
    _id: id
  ,
    Annotation.PUBLIC_FIELDS()

Meteor.publish 'annotations-by-publication', (publicationId) ->
  check publicationId, String

  return unless publicationId

  Annotation.documents.find
    'publication._id': publicationId
  ,
    Annotation.PUBLIC_FIELDS()
