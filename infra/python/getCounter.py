import boto3
import os



def lambda_handler(event, context):
    
    
    record_name="visitors"
    count=0

    #Create DynamoDB client
    dynamodb = boto3.resource('dynamodb')
    #Read environmental variable called TABLE_NAME
    table_name =os.environ["TABLE_NAME"]
    table=dynamodb.Table(table_name)

    #Get current visit count
    response = table.get_item(Key={"counterName" : record_name})

    if "Item" in response:
        count = response ["Item"]["count"]

    #Increment the number of visits
    count+=1

    #Put the new visit count into the table
    table.put_item(Item={"counterName" : record_name, "count":count})

    message=count
    apiResponse = {
        'statusCode':200,
        'headers':{
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': '*'
            },
        "body":message
        }
    return apiResponse
       
        
        
