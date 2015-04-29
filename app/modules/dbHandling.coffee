fs = require('fs')
assert = require('assert')
mongoose = require('mongoose')
path = require('path')
multer = require('multer')
_ = require('underscore')

dbPort = 27017
dbHost = 'localhost'

supportedTemplates = [
  "cards",
  "buckets",
  "sequences"
  ]

currentAssignments = []

studentCollection = "studentCollection"

genericContentSchema = mongoose.Schema({
  indiArg: [],
})

studentSchema = mongoose.Schema({
  username: String,
  password: String,
  teacher: String,
  assignments: []
})

mongoose.connect('mongodb://localhost:27017/brainrushcontent')
mongConnect = mongoose.connection
mongConnect.on('error', console.error.bind(console, 'connect error'))
mongConnect.on('open',(callback)->
  mongConnect.db.collections((err,names)->
    for thisd in names
      for supported in supportedTemplates
        if thisd.s.name.indexOf(supported) > -1
          currentAssignments.push(thisd.s.name)
          break
  )
  ###
  mongConnect.db.collectionNames((err, names)->
    console.log(names)
  )
  ###
  console.log("DATABASE OPENED")
)



#ASSIGNMENT FUNCTIONS
#
#
#

writeDatabaseContent = (arrayToWrite, fileName)->
  contentModel = mongoose.model(fileName, genericContentSchema)
  for argument in arrayToWrite
    do(argument)->
      currContentModel = new contentModel({indiArg:argument})
      contentModel.count({
        indiArg:currContentModel.indiArg
      }, (err, count)->
        if count < 1 && currContentModel.indiArg != undefined
          new contentModel(currContentModel).save()
          return true
        else
          console.log("Exists or is undefined")
          return true
        return false
      )

exports.uploadNewAssignment = (filePath, callback)->
  parsedCSV = parseCSV(filePath)
  fileName = path.basename(filePath)
  csvToDatabase(parsedCSV, fileName)
  updateStudentAssignments(fileName)
  for supported in supportedTemplates
    if fileName.indexOf(supported) > -1
      currentAssignments.push(fileName)
      break
  callback "Uploaded!"


#UTILITY FUNCTIONS
#
#
#
#

csvToDatabase = (arrayToWrite, fileName) ->
  fileName = fileName.split('.')[0]
  checkFile = fileName.split('_')[0]
  if supportedTemplates.indexOf(checkFile) > -1
    writeDatabaseContent(arrayToWrite, fileName)
  else if checkFile == "students"
    addStudentsFromCSV(arrayToWrite)
  else
    console.log "UNSUPPORTED TEMPLATE"

parseCSV = (filePath) ->
  fileData = fs.readFileSync(filePath, 'utf8')
  fileData = fileData.split('\n')
  arrayToReturn = []
  for i in [0..fileData.length-1] by 1
    arrayToReturn[i] = fileData[i].split(',')
  return arrayToReturn

#STUDENT BASED FUNCTIONS
#
#
#
#

addStudentsFromCSV = (parsedStudentCSV, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  for student in parsedStudentCSV
    do(student)->
      currStudent = new studentModel({
        username:student[0],
        password:student[1],
        teacher:student[2],
        assignments:[]
      })
      studentModel.count({
        username:currStudent.username
      }, (err, count)->
        if count < 1 && currStudent.username != undefined
          new studentModel(currStudent).save()
          return true
        else
          console.log("Exists or is undefined")
          return true
        return false
      )

updateStudentAssignments = (assignmentName, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  studentModel.update({},{$push: {assignments:[assignmentName, 0]}}, (err, num)->
    if err
      console.log(err)
    else
      console.log(num)
  )


exports.addStudent = (teacher, username, password, callback) ->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if(username.length > 1 && password.length > 1)
    studentModel.count({username:username},(err, count)->
      if !count
        dataToWrite = new studentModel({
          username:username,
          password:password,
          teacher:teacher,
          assignments:[]
        })
        dataToWrite.save()
        callback "account created", dataToWrite
      else
        callback "account not created"
    )
  else
    callback "username is blank || password is blank"

exports.pullStudents = (teacherName, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  studentModel.find({teacher:teacherName}, '-_id -__v -password', (err, results)->
    if err
      callback err
    else
      callback {students:results, assignments:currentAssignments}
    return
  )
  return

exports.addAssignmentToStudent = (studentName, assignmentName,callback)->


exports.setAssignmentMastery = (assignmentName, student, mastery, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if currentAssignments.indexOf(assignmentName) > -1
    studentModel.findOne({username:student},(err, doc)->
      elementPos = doc.assignments.map((x) ->
        x.assignmentName
      ).indexOf(assignmentName)
      doc.assignments[elementPos].mastery = mastery
      doc.markModified('assignments')
      doc.save()
      callback doc
    )

exports.addAssignmentToAllStudents = (assignmentName, callback)->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if currentAssignments.indexOf(assignmentName) > -1
    studentModel.find({},(err, docs)->
      docs.forEach((doc)->
        doesntExist = true
        for allAssigns in doc.assignments
          if allAssigns.assignmentName == assignmentName
            doesntExist = false
            break
        if doesntExist == true
          studentModel.findByIdAndUpdate(doc.id,
            {$push:{assignments:{assignmentName:assignmentName, mastery:0}}},
            {safe:true, upsert:true},(err, model) ->
              if err
                console.log err
              else
                console.log "LOGGING MODEL"
                console.log model
          )
        else
          console.log "exists!"
        ###
        compare = (a, b) ->
          if a.assignment < b.assignment
            return -1
          if a.assignment > b.assignment
            return 1
          0
        doc.assignments.sort compare
        ###
      )
      callback ("Assignment added:" + assignmentName)
    )
  else
    callback "Assignment does not exist"



exports.pullStudentAssignments = (username, password, callback) ->
  studentModel = mongoose.model(studentCollection, studentSchema)
  if(username.length > 1 && password.length > 1)
    studentModel.find({username:username, password:password}, '-_id -__v', (err, user)->
      if err
        callback err
        return true
      else
        callback user[0].assignments
    )
  else
    callback "username is blank || password is blank"
    return true
  return

exports.pullAssignment = (collectionName, callback) ->
  readFromDatabase(collectionName, cardsSchema, (dataToReturn)->
    callback dataToReturn
  )
  return

readFromDatabase = (collectionName, schema, callback)->
  modelToRead = mongoose.model(collectionName, schema, collectionName)
  modelToRead.find({},'-_id -__v', (err, fullCollection)->
    if err
      callback err
    else
      callback fullCollection
  )
  return
