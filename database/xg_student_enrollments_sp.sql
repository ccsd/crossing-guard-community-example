SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
USE Yours;
GO
ALTER PROCEDURE [dbo].[xg_student_enrollments]
  @user_id VARCHAR(50),
  @section_id INT,
  @status VARCHAR(9)
AS

SET NOCOUNT ON;

EXEC ('SELECT * FROM YOUR.SCH_STUDENT_ENROLLMENTS_VW WHERE user_id = ? AND section_id = ? AND status = ?', @user_id, @section_id, @status)

RETURN

GO