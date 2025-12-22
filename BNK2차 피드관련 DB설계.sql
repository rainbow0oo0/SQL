/*
    날짜 : 2025.11.22
    이름 : 이준우
    내용 : 2차 플러터 FID DB 설계
     - USERS 테이블 기준을 고려
     
     - users Table(참고용)
        "uId"(PK유저 식별번호)
        mid(유저 아이디)
        mpw(유저 비밀번호)
        mname(이름)
        mbirth(생년월일)
        mgender(성별)
        mcarrier(통신사)
        maddress(주소)
        memail(이메일)
        mphone(휴대폰 번호)
        mdate(가입일시)
        mgrade(회원등급)
        mjumin(주민등록번호)
        mcond(상태)
        mnum(고객번호)
        maccess(최근 접속일시)
        mlimit(이체한도)
        mci(인증서)
        role(권한)
*/

/*
    // DB 설계관련 table관련 개인 소감 다음은 이런식으로 table을 구분하고 싶다
     - login : 로그인에 필요한 id, password, role 등을 담는 table 
     - user : 민감한 정보 이름, 주소, 주민등록번호, 약관 동의 여부 즉, 민감한 정보를 담는 table
     - conpany : 기업 회원가입을 개별적으로 1개 더 추가로 만들어서 정보를 담는 table
*/

/*
   1. 프로필 (USERPROFILE)
   - USERS("uId") 1명당 프로필 1개(1:1)
*/
CREATE TABLE USERPROFILE (
    "uId" NUMBER(10) PRIMARY KEY,                 -- PK: USERS("uId")와 동일. (1:1) 프로필의 주인 식별자
    NICKNAME VARCHAR2(50),                        -- 화면 표시용 닉네임(중복 허용/불허 정책에 따라 유니크 인덱스 추가 가능)
    AVATARURL VARCHAR2(500),                      -- 프로필 아이콘/이미지 URL(S3 등). 없으면 기본 이미지 사용
    BIO VARCHAR2(300),                            -- 한 줄 소개/자기소개(짧은 텍스트)
    UPTAT TIMESTAMP DEFAULT SYSTIMESTAMP,         -- 프로필 갱신 시각(수정 시 업데이트해주면 좋음)
    CONSTRAINT FK_USERPROFILE_UID                 -- FK: 프로필은 반드시 USERS에 존재하는 사용자여야 함
        FOREIGN KEY ("uId") REFERENCES USERS("uId")
);

/*
   2. 팔로우 (FOLLOW)
   - 사용자 ↔ 사용자 관계 (N:M)
   - (FOLLOWERuId, FOLLOWINGuId) 복합 PK로 중복 팔로우 방지
*/
CREATE TABLE FOLLOW (
    "FOLLOWERuId"  NUMBER(10) NOT NULL,           -- 팔로우 하는 사람(나) : USERS("uId")
    "FOLLOWINGuId" NUMBER(10) NOT NULL,           -- 팔로우 당하는 사람(상대) : USERS("uId")
    CREATEDAT TIMESTAMP DEFAULT SYSTIMESTAMP,     -- 팔로우 생성 시각(언제부터 팔로우 했는지)
    CONSTRAINT PK_FOLLOW                          -- PK: (나, 상대) 조합이 유일해야 함 → 중복 팔로우 방지
        PRIMARY KEY ("FOLLOWERuId", "FOLLOWINGuId"),
    CONSTRAINT FK_FOLLOWER_UID                    -- FK: FOLLOWERuId는 USERS에 존재해야 함
        FOREIGN KEY ("FOLLOWERuId") REFERENCES USERS("uId"),
    CONSTRAINT FK_FOLLOWING_UID                   -- FK: FOLLOWINGuId는 USERS에 존재해야 함
        FOREIGN KEY ("FOLLOWINGuId") REFERENCES USERS("uId"),
    CONSTRAINT CK_FOLLOW_NOT_SELF                 -- CHECK: 자기 자신을 팔로우 못 하게 막음
        CHECK ("FOLLOWERuId" <> "FOLLOWINGuId")
);

/*
   3. 글(게시판) (POST)
   - 작성자(USERS) 기준의 게시글 테이블
   - POSTTYPE으로 FEED/BOARD 등 확장 가능
*/
CREATE SEQUENCE SEQPOST START WITH 1 INCREMENT BY 1;  -- 게시글 PK(POSTID) 생성용 시퀀스

CREATE TABLE POST (
    POSTID NUMBER(10) PRIMARY KEY,                -- PK: 게시글 번호(보통 SEQPOST.NEXTVAL로 채움)
    "AUTHORuId" NUMBER(10) NOT NULL,              -- FK: 작성자 사용자 ID → USERS("uId")
    POSTTYPE VARCHAR2(20) DEFAULT 'FEED' NOT NULL,-- 게시글 타입(예: FEED/BOARD 등). 추천탭/일반게시판 구분용
    MARKET VARCHAR2(10),                          -- 시장 구분(예: KOR/USA 등). 증권 피드에서 국가/마켓 필터용
    TITLE VARCHAR2(200),                          -- 제목(피드면 비울 수도 있음, 일반게시판이면 사용)
    BODY CLOB NOT NULL,                           -- 본문(긴 글 지원). 피드/게시판 공통 본문
    COVERURL VARCHAR2(500),                       -- 대표 이미지/썸네일 URL(없으면 NULL)
    STATUS VARCHAR2(10) DEFAULT 'ACTIVE' NOT NULL,-- 상태값(ACTIVE/DELETED/BLIND 등 운영용 소프트 삭제)
    CREATEDAT TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL, -- 작성 시각(정렬/최신순 조회 핵심)
    UPDATEDAT TIMESTAMP,                          -- 수정 시각(수정 기능 있으면 업데이트)
    CONSTRAINT FK_POST_AUTHOR_UID                 -- FK: 작성자는 USERS에 반드시 존재해야 함
        FOREIGN KEY ("AUTHORuId") REFERENCES USERS("uId")
);

CREATE INDEX IDX_POST_CREATEDAT ON POST (CREATEDAT DESC);    -- 최신글 조회 성능용(최신순 정렬)
CREATE INDEX IDX_POST_AUTHOR_UID ON POST ("AUTHORuId");      -- 작성자별 글 목록 조회 성능용(내가 쓴 글 등)

/*
   4. 좋아요 (POSTLIKE)
   - 게시글 좋아요(사용자 ↔ 게시글) (N:M)
   - (POSTID, uId) 복합 PK로 동일 사용자의 중복 좋아요 방지
*/
CREATE TABLE POSTLIKE (
    POSTID NUMBER(10) NOT NULL,                   -- FK: 좋아요 대상 게시글 → POST(POSTID)
    "uId" NUMBER(10) NOT NULL,                    -- FK: 좋아요 누른 사용자 → USERS("uId")
    LIKEDAT TIMESTAMP DEFAULT SYSTIMESTAMP,       -- 좋아요 누른 시각(활동 로그/정렬/통계용)
    CONSTRAINT PK_POSTLIKE                         -- PK: (게시글, 사용자) 조합 유일 → 중복 좋아요 방지
        PRIMARY KEY (POSTID, "uId"),
    CONSTRAINT FK_LIKE_POST                        -- FK: POSTID는 POST에 존재해야 함
        FOREIGN KEY (POSTID) REFERENCES POST(POSTID),
    CONSTRAINT FK_LIKE_USER                        -- FK: uId는 USERS에 존재해야 함
        FOREIGN KEY ("uId") REFERENCES USERS("uId")
);

/*
   5. 댓글 (POSTCOMMENT)
   - 게시글에 달리는 댓글
   - 댓글도 STATUS로 소프트 삭제 가능
*/
CREATE SEQUENCE SEQCOMMENT START WITH 1 INCREMENT BY 1;  -- 댓글 PK(COMMENTID) 생성용 시퀀스

CREATE TABLE POSTCOMMENT (
    COMMENTID NUMBER(10) PRIMARY KEY,             -- PK: 댓글 번호(보통 SEQCOMMENT.NEXTVAL로 채움)
    POSTID NUMBER(10) NOT NULL,                   -- FK: 댓글이 달린 게시글 → POST(POSTID)
    "uId" NUMBER(10) NOT NULL,                    -- FK: 댓글 작성자 사용자 ID → USERS("uId")
    BODY VARCHAR2(1000) NOT NULL,                 -- 댓글 내용(짧은 텍스트)
    STATUS VARCHAR2(10) DEFAULT 'ACTIVE' NOT NULL,-- 상태(ACTIVE/DELETED/BLIND 등). 삭제는 보통 소프트 삭제
    CREATEDAT TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL, -- 작성 시각(댓글 최신순/오래된순 정렬)
    CONSTRAINT FK_COMMENT_POST                     -- FK: POSTID는 POST에 존재해야 함
        FOREIGN KEY (POSTID) REFERENCES POST(POSTID),
    CONSTRAINT FK_COMMENT_USER                     -- FK: uId는 USERS에 존재해야 함
        FOREIGN KEY ("uId") REFERENCES USERS("uId")
);

CREATE INDEX IDX_COMMENT_POSTID ON POSTCOMMENT (POSTID, CREATEDAT); -- 게시글별 댓글 목록 조회 성능용

/*
   6. 콘텐츠(기업 글 느낌)
   - 작성자도 USERS("uId")만 바라보게 설계
*/
CREATE SEQUENCE SEQCONTENT START WITH 1 INCREMENT BY 1;  -- 콘텐츠 PK(CONTENTID) 생성용 시퀀스

CREATE TABLE CONTENTARTICLE (
    CONTENTID NUMBER(10) PRIMARY KEY,             -- PK: 콘텐츠 글 번호(보통 SEQCONTENT.NEXTVAL)
    AUTHORuId NUMBER(10) NOT NULL,                -- FK: 작성자 사용자 ID(기업계정) → USERS("uId")
    TITLE VARCHAR2(200) NOT NULL,                 -- 콘텐츠 제목(기업 공지/리포트 등)
    BODY CLOB NOT NULL,                           -- 콘텐츠 본문(긴 글)
    COVERURL VARCHAR2(500),                       -- 대표 이미지/썸네일 URL
    PUBLISHEDAT TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL, -- 발행 시각(콘텐츠 최신순 정렬 핵심)
    STATUS VARCHAR2(10) DEFAULT 'ACTIVE' NOT NULL,-- 상태(ACTIVE/DELETED/BLIND). 운영/검수에 활용
    CONSTRAINT FK_CONTENT_AUTHORuId               -- FK: 작성자는 USERS에 존재해야 함
        FOREIGN KEY (AUTHORuId) REFERENCES USERS("uId")
);

CREATE INDEX IDX_CONTENT_PUBLISHEDAT ON CONTENTARTICLE(PUBLISHEDAT DESC); -- 콘텐츠 최신순 조회 성능용
CREATE INDEX IDX_CONTENT_AUTHORuId ON CONTENTARTICLE(AUTHORuId);          -- 기업(작성자)별 콘텐츠 목록 조회 성능용
