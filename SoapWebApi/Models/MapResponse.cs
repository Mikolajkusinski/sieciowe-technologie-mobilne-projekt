using System.Runtime.Serialization;

namespace SoapWebApi.Models;

[DataContract]
public class MapResponse
{
    [DataMember] 
    public byte[] ImageData { get; set; } = null!;

    [DataMember] 
    public string ContentType { get; set; } = null!;
        
    [DataMember]
    public int Width { get; set; }
        
    [DataMember]
    public int Height { get; set; }

    [DataMember] 
    public string Message { get; set; } = null!;
        
    [DataMember]
    public bool Success { get; set; }
}