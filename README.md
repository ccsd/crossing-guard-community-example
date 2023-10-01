# The Crossing Guard

_A Course People page and +People modal solution for CanvasLMS_

This is a _sidecar_ (not a plugin) for your SIS Integration. Helping to alleviate 
enrollment concerns by grouping SIS ID's into constraints and reconciling them in real time
from the Canvas UI with Live Events.

## Rules of Reconciliation
    
- Students cannot be anything but a student role in the course
- Students cannot be removed from a course the SIS enrolled them in via Canvas
- Students can be manually enrolled (and removed) in a course via Canvas
- Students can be an Observer of a course if they are not enrolled in via SIS
- Teacher of Record cannot be removed from a course via Canvas
- Employees can have any role
- Non-SIS Users can only have the Observer role
- Ignore manually created users with recognized SIS_ID prefix

## Hall Pass & Hall Monitor

The following user groups have a hall pass: `EDDEPT, UNIV, COLL`
- This allows their SIS-ID prefix to walkabout SIS courses without restriction.

The following user groups are restricted to non sis courses: `DEPT, ANOTH, VENDOR`
- Enrollments in SIS courses with Students will be rejected.

The following user groups are allowed in their respective courses/accounts: `PLS`
- Professional Learning users can be enrolled in PLS courses in PLS accounts.

The following user groups are allowed in their respective courses/accounts: `DEMO-student`
- DEMO users are restricted to DEMO sub accounts.


## Live Events
Create a Live Events subscription for the user-generated `enrollment_created` and `enrollment_updated` events.

## Discuss
https://community.canvaslms.com/t5/Canvas-Developers-Group/The-Crossing-Guard/m-p/582594#M9651


#
> This repo is provided as an example of possibilities, your rules will be different from ours... just adapt it to your needs. 

`Star it` if it's useful for you.

![Elvis Panda](https://s3-us-west-2.amazonaws.com/ccsd-canvas/branding/images/ccsd-elvis-panda-sm.png "Elvis Panda")